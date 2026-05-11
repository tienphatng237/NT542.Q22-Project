# ============================================================================
# CIS BENCHMARK LEVEL 1 - AUDITING & MONITORING REMEDIATION
# Scope: 2.3.2, 17.x, 18.10.26
# ============================================================================

$ErrorActionPreference = "Stop"

$BaseDir = "C:\CIS-Automation"
$LogDir = "$BaseDir\Logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

$StartTime = Get-Date
$TimestampFile = $StartTime.ToString("yyyyMMdd_HHmmss")
$TimestampDisplay = $StartTime.ToString("dd/MM/yyyy HH:mm:ss")
$LogFile = "$LogDir\Auditing-Monitoring-Remediation-$TimestampFile.log"

Start-Transcript -Path $LogFile -Force

function Ensure-RegistryPath {
    param([string]$RegPath)

    if (Test-Path $RegPath) { return }

    $Parent = Split-Path -Path $RegPath -Parent
    if ($Parent -and -not (Test-Path $Parent)) {
        Ensure-RegistryPath -RegPath $Parent
    }

    New-Item -Path $RegPath -Force | Out-Null
}

function Set-RegistryRule {
    param([pscustomobject]$Rule)

    Ensure-RegistryPath -RegPath $Rule.Path

    $RegType = if ($Rule.PSObject.Properties.Name -contains "ValueType" -and $Rule.ValueType) {
        [string]$Rule.ValueType
    } else {
        "DWord"
    }

    if (-not (Get-ItemProperty -Path $Rule.Path -Name $Rule.Key -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $Rule.Path -Name $Rule.Key -PropertyType $RegType -Value $Rule.ExpectedValue -Force | Out-Null
    }

    Set-ItemProperty -Path $Rule.Path -Name $Rule.Key -Value $Rule.ExpectedValue -Force
}

function Set-AuditPolRule {
    param([pscustomobject]$Rule)

    switch ([string]$Rule.ExpectedValue) {
        "Success" {
            auditpol /set /subcategory:"$($Rule.Subcategory)" /success:enable /failure:disable | Out-Null
        }
        "Failure" {
            auditpol /set /subcategory:"$($Rule.Subcategory)" /success:disable /failure:enable | Out-Null
        }
        "Success and Failure" {
            auditpol /set /subcategory:"$($Rule.Subcategory)" /success:enable /failure:enable | Out-Null
        }
        "No Auditing" {
            auditpol /set /subcategory:"$($Rule.Subcategory)" /success:disable /failure:disable | Out-Null
        }
        default {
            throw "Unsupported audit policy value: $($Rule.ExpectedValue)"
        }
    }
}

$RegistryRules = @(
    [PSCustomObject]@{ CisId="2.3.2.1"; Path="HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"; Key="SCENoApplyLegacyAuditPolicy"; ValueType="DWord"; ExpectedValue=1 }
    [PSCustomObject]@{ CisId="2.3.2.2"; Path="HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"; Key="CrashOnAuditFail"; ValueType="DWord"; ExpectedValue=0 }

    [PSCustomObject]@{ CisId="18.10.26.1.1"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application"; Key="Retention"; ValueType="DWord"; ExpectedValue=0 }
    [PSCustomObject]@{ CisId="18.10.26.1.2"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application"; Key="MaxSize"; ValueType="DWord"; ExpectedValue=32768 }
    [PSCustomObject]@{ CisId="18.10.26.2.1"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security"; Key="Retention"; ValueType="DWord"; ExpectedValue=0 }
    [PSCustomObject]@{ CisId="18.10.26.2.2"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security"; Key="MaxSize"; ValueType="DWord"; ExpectedValue=196608 }
    [PSCustomObject]@{ CisId="18.10.26.3.1"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Setup"; Key="Retention"; ValueType="DWord"; ExpectedValue=0 }
    [PSCustomObject]@{ CisId="18.10.26.3.2"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Setup"; Key="MaxSize"; ValueType="DWord"; ExpectedValue=32768 }
    [PSCustomObject]@{ CisId="18.10.26.4.1"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System"; Key="Retention"; ValueType="DWord"; ExpectedValue=0 }
    [PSCustomObject]@{ CisId="18.10.26.4.2"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System"; Key="MaxSize"; ValueType="DWord"; ExpectedValue=32768 }
)

$AuditPolRules = @(
    [PSCustomObject]@{ CisId="17.1.1"; Subcategory="{0cce923f-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.1.2"; Subcategory="{0cce9242-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.1.3"; Subcategory="{0cce9240-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.2.1"; Subcategory="{0cce9239-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.2.2"; Subcategory="{0cce9236-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.2.3"; Subcategory="{0cce9238-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.2.4"; Subcategory="{0cce923a-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.2.5"; Subcategory="{0cce9237-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.2.6"; Subcategory="{0cce9235-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.3.1"; Subcategory="{0cce9248-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.3.2"; Subcategory="{0cce922b-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.4.1"; Subcategory="{0cce923b-69ae-11d9-bed3-505054503030}"; ExpectedValue="Failure" }
    [PSCustomObject]@{ CisId="17.4.2"; Subcategory="{0cce923c-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.5.1"; Subcategory="{0cce9217-69ae-11d9-bed3-505054503030}"; ExpectedValue="Failure" }
    [PSCustomObject]@{ CisId="17.5.2"; Subcategory="{0cce9249-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.5.3"; Subcategory="{0cce9216-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.5.4"; Subcategory="{0cce9215-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.5.5"; Subcategory="{0cce921c-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.5.6"; Subcategory="{0cce921b-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.6.1"; Subcategory="{0cce9244-69ae-11d9-bed3-505054503030}"; ExpectedValue="Failure" }
    [PSCustomObject]@{ CisId="17.6.2"; Subcategory="{0cce9224-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.6.3"; Subcategory="{0cce9227-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.6.4"; Subcategory="{0cce9245-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.7.1"; Subcategory="{0cce922f-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.7.2"; Subcategory="{0cce9230-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.7.3"; Subcategory="{0cce9231-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.7.4"; Subcategory="{0cce9232-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.7.5"; Subcategory="{0cce9234-69ae-11d9-bed3-505054503030}"; ExpectedValue="Failure" }
    [PSCustomObject]@{ CisId="17.8.1"; Subcategory="{0cce9228-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.9.1"; Subcategory="{0cce9213-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.9.2"; Subcategory="{0cce9214-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ CisId="17.9.3"; Subcategory="{0cce9210-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.9.4"; Subcategory="{0cce9211-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ CisId="17.9.5"; Subcategory="{0cce9212-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
)

$PassCount = 0
$FailCount = 0

Write-Host "==============================================================================="
Write-Host " BAT DAU REMEDIATION - MODULE AUDITING & MONITORING"
Write-Host " Thoi gian bat dau : $TimestampDisplay"
Write-Host " Tong so Registry rule : $($RegistryRules.Count)"
Write-Host " Tong so AuditPol rule : $($AuditPolRules.Count)"
Write-Host "==============================================================================="

foreach ($Rule in $RegistryRules) {
    try {
        Set-RegistryRule -Rule $Rule
        $PassCount++
        Write-Host "[PASS] $($Rule.CisId) -> Registry applied"
    }
    catch {
        $FailCount++
        Write-Host "[FAIL] $($Rule.CisId) -> $($_.Exception.Message)"
    }
}

foreach ($Rule in $AuditPolRules) {
    try {
        Set-AuditPolRule -Rule $Rule
        $PassCount++
        Write-Host "[PASS] $($Rule.CisId) -> Audit policy applied"
    }
    catch {
        $FailCount++
        Write-Host "[FAIL] $($Rule.CisId) -> $($_.Exception.Message)"
    }
}

Write-Host "[INFO] Running gpupdate /force ..."
gpupdate /force /wait:0 | Out-Null

$EndTime = Get-Date
Write-Host "==============================================================================="
Write-Host " HOAN TAT REMEDIATION - MODULE AUDITING & MONITORING"
Write-Host " Thoi gian ket thuc : $($EndTime.ToString('dd/MM/yyyy HH:mm:ss'))"
Write-Host " PASS: $PassCount | FAIL: $FailCount"
Write-Host " Log file: $LogFile"
Write-Host "==============================================================================="

Stop-Transcript
