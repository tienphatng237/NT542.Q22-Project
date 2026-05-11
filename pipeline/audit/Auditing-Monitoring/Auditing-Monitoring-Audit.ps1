# ============================================================================
# CIS BENCHMARK LEVEL 1 - AUDITING & MONITORING AUDIT
# Scope: 2.3.2, 17.x, 18.10.26
# Output: Console + JSON + HTML
# ============================================================================

$ErrorActionPreference = "Stop"

$BaseDir = "C:\CIS-Automation"
$Paths = @(
    "$BaseDir\Scripts",
    "$BaseDir\Reports\HTML",
    "$BaseDir\Reports\JSON",
    "$BaseDir\Logs"
)
foreach ($PathItem in $Paths) {
    if (-not (Test-Path $PathItem)) {
        New-Item -ItemType Directory -Force -Path $PathItem | Out-Null
    }
}

$StartTime = Get-Date
$TimestampFile = $StartTime.ToString("yyyyMMdd_HHmmss")
$TimestampDisplay = $StartTime.ToString("dd/MM/yyyy HH:mm:ss")
$OSInfo = (Get-CimInstance Win32_OperatingSystem).Caption

$Results = @()

function Normalize-AuditSetting {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return "Unknown" }
    $Text = $Value.Trim().ToLowerInvariant()

    if ($Text -match "no auditing") { return "No Auditing" }
    if ($Text -match "success and failure") { return "Success and Failure" }
    if ($Text -match "failure and success") { return "Success and Failure" }
    if ($Text -match "success" -and $Text -notmatch "failure") { return "Success" }
    if ($Text -match "failure" -and $Text -notmatch "success") { return "Failure" }

    return $Value.Trim()
}

function Add-Result {
    param(
        [string]$CisId,
        [string]$Type,
        [string]$Description,
        [string]$Expected,
        [string]$Current,
        [string]$Status
    )

    $script:Results += [PSCustomObject]@{
        CIS_ID      = $CisId
        Type        = $Type
        Description = $Description
        Expected    = $Expected
        Current     = $Current
        Status      = $Status
    }
}

function Test-RegistryRule {
    param([pscustomobject]$Rule)

    $CurrentValue = "Not Found"
    $Status = "FAIL"
    $Mode = ([string]$Rule.CompareType).Trim().ToLowerInvariant()

    try {
        $Value = Get-ItemPropertyValue -Path $Rule.Path -Name $Rule.Key -ErrorAction Stop
        $CurrentValue = [string]$Value

        switch ($Mode) {
            "equals" {
                if ([string]$Value -eq [string]$Rule.ExpectedValue) { $Status = "PASS" }
            }
            "equalsorgreater" {
                if ([double]$Value -ge [double]$Rule.ExpectedValue) { $Status = "PASS" }
            }
            default {
                if ([string]$Value -eq [string]$Rule.ExpectedValue) { $Status = "PASS" }
            }
        }
    } catch {
        $CurrentValue = "Not Found"
    }

    Add-Result `
        -CisId $Rule.CisId `
        -Type "Registry" `
        -Description $Rule.Description `
        -Expected ([string]$Rule.ExpectedValue) `
        -Current $CurrentValue `
        -Status $Status
}

function Get-AuditPolInclusionSetting {
    param([string]$SubcategoryGuid)

    $Raw = @()
    try {
        $Raw = & auditpol /get /subcategory:"$SubcategoryGuid" /r 2>$null
    } catch {
        return "Unknown"
    }

    if (-not $Raw -or $Raw.Count -eq 0) {
        return "Unknown"
    }

    try {
        $Csv = $Raw | ConvertFrom-Csv
        if ($Csv -and $Csv.Count -gt 0) {
            $Row = $Csv | Select-Object -First 1
            foreach ($ColumnName in @("Inclusion Setting","Setting Value","Setting")) {
                if ($Row.PSObject.Properties.Name -contains $ColumnName) {
                    return (Normalize-AuditSetting -Value ([string]$Row.$ColumnName))
                }
            }
        }
    } catch {
    }

    $Text = ($Raw | Out-String)
    return (Normalize-AuditSetting -Value $Text)
}

function Test-AuditPolRule {
    param([pscustomobject]$Rule)

    $CurrentSetting = Get-AuditPolInclusionSetting -SubcategoryGuid $Rule.Subcategory
    $ExpectedSetting = Normalize-AuditSetting -Value $Rule.ExpectedValue
    $Status = if ($CurrentSetting -eq $ExpectedSetting) { "PASS" } else { "FAIL" }

    Add-Result `
        -CisId $Rule.CisId `
        -Type "AuditPol" `
        -Description $Rule.Description `
        -Expected $ExpectedSetting `
        -Current $CurrentSetting `
        -Status $Status
}

$AuditRules = @(
    [PSCustomObject]@{
        Type = "Registry"
        CisId = "2.3.2.1"
        Description = "Ensure 'Audit: Force audit policy subcategory settings (Windows Vista or later) to override audit policy category settings' is set to 'Enabled'"
        Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Key = "SCENoApplyLegacyAuditPolicy"
        CompareType = "Equals"
        ExpectedValue = 1
    },
    [PSCustomObject]@{
        Type = "Registry"
        CisId = "2.3.2.2"
        Description = "Ensure 'Audit: Shut down system immediately if unable to log security audits' is set to 'Disabled'"
        Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Key = "CrashOnAuditFail"
        CompareType = "Equals"
        ExpectedValue = 0
    }
)

$AdvancedAuditRules = @(
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.1.1"; Description="Audit Credential Validation"; Subcategory="{0cce923f-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.1.2"; Description="Audit Kerberos Authentication Service"; Subcategory="{0cce9242-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.1.3"; Description="Audit Kerberos Service Ticket Operations"; Subcategory="{0cce9240-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.2.1"; Description="Audit Application Group Management"; Subcategory="{0cce9239-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.2.2"; Description="Audit Computer Account Management"; Subcategory="{0cce9236-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.2.3"; Description="Audit Distribution Group Management"; Subcategory="{0cce9238-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.2.4"; Description="Audit Other Account Management Events"; Subcategory="{0cce923a-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.2.5"; Description="Audit Security Group Management"; Subcategory="{0cce9237-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.2.6"; Description="Audit User Account Management"; Subcategory="{0cce9235-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.3.1"; Description="Audit PNP Activity"; Subcategory="{0cce9248-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.3.2"; Description="Audit Process Creation"; Subcategory="{0cce922b-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.4.1"; Description="Audit Directory Service Access"; Subcategory="{0cce923b-69ae-11d9-bed3-505054503030}"; ExpectedValue="Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.4.2"; Description="Audit Directory Service Changes"; Subcategory="{0cce923c-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.5.1"; Description="Audit Account Lockout"; Subcategory="{0cce9217-69ae-11d9-bed3-505054503030}"; ExpectedValue="Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.5.2"; Description="Audit Group Membership"; Subcategory="{0cce9249-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.5.3"; Description="Audit Logoff"; Subcategory="{0cce9216-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.5.4"; Description="Audit Logon"; Subcategory="{0cce9215-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.5.5"; Description="Audit Other Logon/Logoff Events"; Subcategory="{0cce921c-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.5.6"; Description="Audit Special Logon"; Subcategory="{0cce921b-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.6.1"; Description="Audit Detailed File Share"; Subcategory="{0cce9244-69ae-11d9-bed3-505054503030}"; ExpectedValue="Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.6.2"; Description="Audit File Share"; Subcategory="{0cce9224-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.6.3"; Description="Audit Other Object Access Events"; Subcategory="{0cce9227-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.6.4"; Description="Audit Removable Storage"; Subcategory="{0cce9245-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.7.1"; Description="Audit Audit Policy Change"; Subcategory="{0cce922f-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.7.2"; Description="Audit Authentication Policy Change"; Subcategory="{0cce9230-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.7.3"; Description="Audit Authorization Policy Change"; Subcategory="{0cce9231-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.7.4"; Description="Audit MPSSVC Rule-Level Policy Change"; Subcategory="{0cce9232-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.7.5"; Description="Audit Other Policy Change Events"; Subcategory="{0cce9234-69ae-11d9-bed3-505054503030}"; ExpectedValue="Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.8.1"; Description="Audit Sensitive Privilege Use"; Subcategory="{0cce9228-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.9.1"; Description="Audit IPsec Driver"; Subcategory="{0cce9213-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.9.2"; Description="Audit Other System Events"; Subcategory="{0cce9214-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.9.3"; Description="Audit Security State Change"; Subcategory="{0cce9210-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.9.4"; Description="Audit Security System Extension"; Subcategory="{0cce9211-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success" }
    [PSCustomObject]@{ Type="AuditPol"; CisId="17.9.5"; Description="Audit System Integrity"; Subcategory="{0cce9212-69ae-11d9-bed3-505054503030}"; ExpectedValue="Success and Failure" }
)

$EventLogServiceAudit = @(
    [PSCustomObject]@{ Type="Registry"; CisId="18.10.26.1.1"; Description="Application: Control Event Log behavior when the log file reaches its maximum size"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application"; Key="Retention"; CompareType="Equals"; ExpectedValue=0 }
    [PSCustomObject]@{ Type="Registry"; CisId="18.10.26.1.2"; Description="Application: Specify the maximum log file size (KB)"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application"; Key="MaxSize"; CompareType="Equals"; ExpectedValue=32768 }
    [PSCustomObject]@{ Type="Registry"; CisId="18.10.26.2.1"; Description="Security: Control Event Log behavior when the log file reaches its maximum size"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security"; Key="Retention"; CompareType="Equals"; ExpectedValue=0 }
    [PSCustomObject]@{ Type="Registry"; CisId="18.10.26.2.2"; Description="Security: Specify the maximum log file size (KB)"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security"; Key="MaxSize"; CompareType="Equals"; ExpectedValue=196608 }
    [PSCustomObject]@{ Type="Registry"; CisId="18.10.26.3.1"; Description="Setup: Control Event Log behavior when the log file reaches its maximum size"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Setup"; Key="Retention"; CompareType="Equals"; ExpectedValue=0 }
    [PSCustomObject]@{ Type="Registry"; CisId="18.10.26.3.2"; Description="Setup: Specify the maximum log file size (KB)"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Setup"; Key="MaxSize"; CompareType="EqualsOrGreater"; ExpectedValue=32768 }
    [PSCustomObject]@{ Type="Registry"; CisId="18.10.26.4.1"; Description="System: Control Event Log behavior when the log file reaches its maximum size"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System"; Key="Retention"; CompareType="Equals"; ExpectedValue=0 }
    [PSCustomObject]@{ Type="Registry"; CisId="18.10.26.4.2"; Description="System: Specify the maximum log file size (KB)"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System"; Key="MaxSize"; CompareType="EqualsOrGreater"; ExpectedValue=32768 }
)

$Rules = $AuditRules + $AdvancedAuditRules + $EventLogServiceAudit

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host " BAT DAU QUET (AUDIT) - MODULE AUDITING & MONITORING" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host " Thoi gian bat dau : $TimestampDisplay" -ForegroundColor Cyan
Write-Host " He dieu hanh      : $OSInfo" -ForegroundColor Cyan
Write-Host " Tong so rule      : $($Rules.Count)" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan

foreach ($Rule in $Rules) {
    if ($Rule.Type -eq "Registry") {
        Test-RegistryRule -Rule $Rule
    } elseif ($Rule.Type -eq "AuditPol") {
        Test-AuditPolRule -Rule $Rule
    }
}

$PassCount = @($Results | Where-Object { $_.Status -eq "PASS" }).Count
$FailCount = @($Results | Where-Object { $_.Status -eq "FAIL" }).Count
$TotalCount = $Results.Count
$PassPct = if ($TotalCount -gt 0) { [math]::Round(($PassCount / $TotalCount) * 100, 2) } else { 0 }

Write-Host "`n====================="
Write-Host "AUDIT COMPLETE"
Write-Host "Total Rules   : $TotalCount"
Write-Host "Total PASS    : $PassCount"
Write-Host "Total FAIL    : $FailCount"
Write-Host "Pass Rate (%) : $PassPct"
Write-Host "=====================`n"
$Results | Format-Table CIS_ID,Type,Expected,Current,Status -AutoSize

$JsonPath = "$BaseDir\Reports\JSON\Auditing-Monitoring-Audit-$TimestampFile.json"
$HtmlPath = "$BaseDir\Reports\HTML\Auditing-Monitoring-Audit-$TimestampFile.html"

$Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $JsonPath -Encoding UTF8

$Head = @"
<style>
body { font-family: Segoe UI, Arial, sans-serif; padding: 20px; color: #222; }
h1 { margin-bottom: 0; }
.meta { margin-top: 4px; margin-bottom: 16px; color: #555; }
.summary { margin: 12px 0 18px 0; font-weight: 600; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { border: 1px solid #d9d9d9; padding: 6px 8px; text-align: left; vertical-align: top; }
th { background: #f3f6fa; }
.pass { color: #0a7d34; font-weight: 600; }
.fail { color: #c62828; font-weight: 600; }
</style>
"@

$HtmlTableRows = $Results | Select-Object CIS_ID,Type,Description,Expected,Current,Status |
    ConvertTo-Html -Fragment
$HtmlDoc = @"
<html>
<head>
<meta charset="UTF-8">
<title>CIS Audit Report - Auditing & Monitoring</title>
$Head
</head>
<body>
<h1>CIS Audit Report - Auditing & Monitoring</h1>
<div class="meta">Generated: $TimestampDisplay</div>
<div class="meta">OS: $OSInfo</div>
<div class="summary">PASS: $PassCount | FAIL: $FailCount | TOTAL: $TotalCount | PASS RATE: $PassPct%</div>
$HtmlTableRows
</body>
</html>
"@
$HtmlDoc | Out-File -FilePath $HtmlPath -Encoding UTF8

Write-Host " [JSON Report] : $JsonPath" -ForegroundColor Yellow
Write-Host " [HTML Report] : $HtmlPath" -ForegroundColor Yellow
