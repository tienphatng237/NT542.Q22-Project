# Run this script in an elevated PowerShell session on the GOLDEN Windows image
# before Sysprep. It downloads the official Windows 11 24H2 ADMX package,
# backs up local PolicyDefinitions, and copies the new templates into place.

[CmdletBinding()]
param(
  [string]$ConfirmationUrl = "https://www.microsoft.com/en-us/download/details.aspx?id=106254",
  [string]$Language = "en-US",
  [string]$WorkingDirectory = "C:\Temp\admx-24H2",
  [string]$BackupRoot = "C:\Backup\PolicyDefinitions",
  [string[]]$TemplateNames = @("WindowsDefender"),
  [switch]$SkipBackup
)

$ErrorActionPreference = "Stop"

function Assert-Administrator {
  $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run in an elevated PowerShell session."
  }
}

function New-CleanDirectory {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }

  New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Resolve-MsiDownloadUrl {
  param([Parameter(Mandatory = $true)][string]$Url)

  $response = Invoke-WebRequest -Uri $Url -UseBasicParsing

  $candidateLinks = @()

  if ($response.Links) {
    $candidateLinks += $response.Links |
      Where-Object { $_.href -match '\.msi($|\?)' } |
      ForEach-Object { $_.href }
  }

  if (-not $candidateLinks -and $response.Content) {
    $candidateLinks += [regex]::Matches($response.Content, 'https://download\.microsoft\.com/[^"\''\s>]+\.msi') |
      ForEach-Object { $_.Value }
  }

  $resolvedUrl = $candidateLinks |
    Where-Object { $_ -match '^https://download\.microsoft\.com/' } |
    Select-Object -First 1

  if (-not $resolvedUrl) {
    throw "Could not resolve MSI download URL from confirmation page: $Url"
  }

  return $resolvedUrl
}

function Grant-FileReplacePermission {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  & takeown.exe /F $Path /A | Out-Null
  & icacls.exe $Path /grant "Administrators:F" /C | Out-Null
}

Assert-Administrator

$msiPath = Join-Path $WorkingDirectory "windows-11-24h2-admx.msi"
$extractPath = Join-Path $WorkingDirectory "extracted"
$destinationPolicyDefinitions = "C:\Windows\PolicyDefinitions"
$destinationLanguagePath = Join-Path $destinationPolicyDefinitions $Language
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "[1/7] Preparing working directories..."
New-CleanDirectory -Path $WorkingDirectory
New-CleanDirectory -Path $extractPath

Write-Host "[2/7] Resolving official ADMX package from Microsoft confirmation page..."
$downloadUrl = Resolve-MsiDownloadUrl -Url $ConfirmationUrl
Write-Host "Resolved MSI URL: $downloadUrl"
Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath

Write-Host "[3/7] Extracting MSI contents..."
$extractArguments = @(
  "/a"
  "`"$msiPath`""
  "/qn"
  "TARGETDIR=`"$extractPath`""
)
$extractProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $extractArguments -Wait -PassThru
if ($extractProcess.ExitCode -ne 0) {
  throw "msiexec failed with exit code $($extractProcess.ExitCode)."
}

Write-Host "[4/7] Locating extracted PolicyDefinitions..."
$sourcePolicyDefinitions = Get-ChildItem -Path $extractPath -Directory -Recurse |
  Where-Object { $_.Name -eq "PolicyDefinitions" } |
  Select-Object -First 1 -ExpandProperty FullName

if (-not $sourcePolicyDefinitions) {
  throw "Could not find extracted PolicyDefinitions directory."
}

$sourceLanguagePath = Join-Path $sourcePolicyDefinitions $Language
if (-not (Test-Path -LiteralPath $sourceLanguagePath)) {
  throw "Language folder not found in extracted templates: $sourceLanguagePath"
}

if (-not $SkipBackup.IsPresent) {
  Write-Host "[5/7] Backing up current local PolicyDefinitions..."
  $backupPath = Join-Path $BackupRoot $timestamp
  New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

  foreach ($templateName in $TemplateNames) {
    $existingAdmx = Join-Path $destinationPolicyDefinitions "$templateName.admx"
    $existingAdml = Join-Path $destinationLanguagePath "$templateName.adml"

    if (Test-Path -LiteralPath $existingAdmx) {
      Copy-Item -Path $existingAdmx -Destination $backupPath -Force
    }

    if (Test-Path -LiteralPath $existingAdml) {
      $backupLanguagePath = Join-Path $backupPath $Language
      New-Item -ItemType Directory -Path $backupLanguagePath -Force | Out-Null
      Copy-Item -Path $existingAdml -Destination $backupLanguagePath -Force
    }
  }

  Write-Host "Backup created at: $backupPath"
} else {
  Write-Host "[5/7] Skipping backup as requested..."
}

Write-Host "[6/7] Copying ADMX/ADML files into local PolicyDefinitions..."
New-Item -ItemType Directory -Path $destinationLanguagePath -Force | Out-Null

foreach ($templateName in $TemplateNames) {
  $sourceAdmx = Join-Path $sourcePolicyDefinitions "$templateName.admx"
  $sourceAdml = Join-Path $sourceLanguagePath "$templateName.adml"
  $destinationAdmx = Join-Path $destinationPolicyDefinitions "$templateName.admx"
  $destinationAdml = Join-Path $destinationLanguagePath "$templateName.adml"

  if (-not (Test-Path -LiteralPath $sourceAdmx)) {
    throw "Source ADMX not found: $sourceAdmx"
  }

  if (-not (Test-Path -LiteralPath $sourceAdml)) {
    throw "Source ADML not found: $sourceAdml"
  }

  Grant-FileReplacePermission -Path $destinationAdmx
  Grant-FileReplacePermission -Path $destinationAdml

  Copy-Item -Path $sourceAdmx -Destination $destinationAdmx -Force
  Copy-Item -Path $sourceAdml -Destination $destinationAdml -Force
}

Write-Host "[7/7] Verifying Windows Defender ADMX presence..."
$defenderAdmxPath = Join-Path $destinationPolicyDefinitions "WindowsDefender.admx"
if (-not (Test-Path -LiteralPath $defenderAdmxPath)) {
  throw "WindowsDefender.admx was not found after copy."
}

$edrPatternFound = Select-String -Path $defenderAdmxPath -Pattern "PassiveRemediation" -SimpleMatch -Quiet
if ($edrPatternFound) {
  Write-Host "Verification succeeded: WindowsDefender.admx contains PassiveRemediation."
} else {
  Write-Warning "WindowsDefender.admx copied, but PassiveRemediation was not found in the file."
}

Write-Host ""
Write-Host "Done. Recommended next steps:"
Write-Host "1. Reopen gpedit.msc and verify the newer Defender policies appear."
Write-Host "2. If the golden image is ready, run Sysprep and rebuild win2k22-golden.qcow2."

$src = "C:\Program Files (x86)\Microsoft Group Policy\Windows 11 Sep 2024 Update (24H2)\PolicyDefinitions"

takeown /F "C:\Windows\PolicyDefinitions\AccountNotifications.admx" /A
icacls "C:\Windows\PolicyDefinitions\AccountNotifications.admx" /grant Administrators:F

takeown /F "C:\Windows\PolicyDefinitions\en-US\AccountNotifications.adml" /A
icacls "C:\Windows\PolicyDefinitions\en-US\AccountNotifications.adml" /grant Administrators:F

Copy-Item "$src\AccountNotifications.admx" "C:\Windows\PolicyDefinitions\" -Force
Copy-Item "$src\en-US\AccountNotifications.adml" "C:\Windows\PolicyDefinitions\en-US\" -Force
