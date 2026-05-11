# 1. SETUP DIRECTORIES & TIMESTAMPS
$BaseDir = "C:\CIS-Automation"
$Paths = @("$BaseDir\Scripts", "$BaseDir\Reports\HTML", "$BaseDir\Reports\JSON", "$BaseDir\Logs")
foreach ($p in $Paths) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

$StartTime = Get-Date
$TimestampFile = $StartTime.ToString("yyyyMMdd_HHmmss")
$TimestampDisplay = $StartTime.ToString("dd/MM/yyyy HH:mm:ss")
$OSInfo = (Get-CimInstance Win32_OperatingSystem).Caption

# Khớp cấu trúc tìm file template giống với Network Script
$PipelineRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$TemplateDir = Join-Path $PipelineRoot "templates"
$CssTemplatePath = Join-Path $TemplateDir "cis-audit-report.css"
$HtmlTemplatePath = Join-Path $TemplateDir "cis-audit-report.html.tpl"

# 2. CONSOLE HEADER
Clear-Host
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host " BAT DAU QUET (AUDIT) - MODULE IDENTITY & ACCESS CONTROL (FULL)" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host " Thoi gian bat dau : $TimestampDisplay" -ForegroundColor Cyan
Write-Host " He dieu hanh      : $OSInfo" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# Xuất cấu hình bảo mật cục bộ ra file tạm để phục vụ cho Module Identity
$SecPolPath = "$env:TEMP\secpol_audit.cfg"
secedit /export /cfg $SecPolPath /quiet | Out-Null
$SecPol = Get-Content $SecPolPath

# 3. DEFINE AUDIT RULES
$AuditRules = @(
    # --- PART 1.1: PASSWORD POLICY ---
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.1"; SubName="Password Policy"; CisId="1.1.1"; Desc="Ensure 'Enforce password history' is set to '24 or more password(s)'"; Expected="24"; CheckType="History" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.1"; SubName="Password Policy"; CisId="1.1.2"; Desc="Ensure 'Maximum password age' is set to '365 or fewer days'"; Expected="365"; CheckType="MaxAge" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.1"; SubName="Password Policy"; CisId="1.1.3"; Desc="Ensure 'Minimum password age' is set to '1 or more day(s)'"; Expected="1"; CheckType="MinAge" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.1"; SubName="Password Policy"; CisId="1.1.4"; Desc="Ensure 'Minimum password length' is set to '14 or more'"; Expected="14"; CheckType="MinLength" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.1"; SubName="Password Policy"; CisId="1.1.5"; Desc="Ensure 'Password must meet complexity requirements' is set to 'Enabled'"; Expected="1"; CheckType="Complexity" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.1"; SubName="Password Policy"; CisId="1.1.6"; Desc="Ensure 'Relax minimum password length limits' is set to 'Enabled'"; Expected="1"; CheckType="RelaxMinLength" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.1"; SubName="Password Policy"; CisId="1.1.7"; Desc="Ensure 'Store passwords using reversible encryption' is set to 'Disabled'"; Expected="0"; CheckType="ClearText" }

    # --- PART 1.2: ACCOUNT LOCKOUT POLICY ---
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.2"; SubName="Account Lockout"; CisId="1.2.1"; Desc="Ensure 'Account lockout duration' is set to '15 or more minute(s)'"; Expected="15"; CheckType="LockoutDuration" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.2"; SubName="Account Lockout"; CisId="1.2.2"; Desc="Ensure 'Account lockout threshold' is set to '5 or fewer'"; Expected="5"; CheckType="LockoutThreshold" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.2"; SubName="Account Lockout"; CisId="1.2.3"; Desc="Ensure 'Allow Administrator account lockout' is set to 'Enabled'"; Expected="1"; CheckType="AdminLockout" }
    [PSCustomObject]@{ GrpId="1"; GrpName="Account Policies"; SubId="1.2"; SubName="Account Lockout"; CisId="1.2.4"; Desc="Ensure 'Reset account lockout counter after' is set to '15 or more'"; Expected="15"; CheckType="LockoutWindow" }

    # --- PART 2.2: USER RIGHTS ASSIGNMENT ---
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.1"; Desc="Access Credential Manager as a trusted caller"; Expected="No One"; CheckType="UserRight"; SecKey="SeTrustedCredManAccessPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.2"; Desc="Access this computer from the network"; Expected="Configured"; CheckType="UserRight"; SecKey="SeNetworkLogonRight"; FixSids="*S-1-5-32-544,*S-1-5-11" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.4"; Desc="Act as part of the operating system"; Expected="No One"; CheckType="UserRight"; SecKey="SeTcbPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.5"; Desc="Add workstations to domain"; Expected="Configured"; CheckType="UserRight"; SecKey="SeMachineAccountPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.6"; Desc="Adjust memory quotas for a process"; Expected="Configured"; CheckType="UserRight"; SecKey="SeIncreaseQuotaPrivilege"; FixSids="*S-1-5-32-544,*S-1-5-19,*S-1-5-20" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.7"; Desc="Allow log on locally"; Expected="Configured"; CheckType="UserRight"; SecKey="SeInteractiveLogonRight"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.9"; Desc="Allow log on through Remote Desktop Services"; Expected="Configured"; CheckType="UserRight"; SecKey="SeRemoteInteractiveLogonRight"; FixSids="*S-1-5-32-544,*S-1-5-32-555" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.11"; Desc="Back up files and directories"; Expected="Configured"; CheckType="UserRight"; SecKey="SeBackupPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.12"; Desc="Change the system time"; Expected="Configured"; CheckType="UserRight"; SecKey="SeSystemtimePrivilege"; FixSids="*S-1-5-32-544,*S-1-5-19" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.13"; Desc="Create a pagefile"; Expected="Configured"; CheckType="UserRight"; SecKey="SeCreatePagefilePrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.14"; Desc="Create a token object"; Expected="No One"; CheckType="UserRight"; SecKey="SeCreateTokenPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.15"; Desc="Create global objects"; Expected="Configured"; CheckType="UserRight"; SecKey="SeCreateGlobalPrivilege"; FixSids="*S-1-5-32-544,*S-1-5-19,*S-1-5-20,*S-1-5-6" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.16"; Desc="Create permanent shared objects"; Expected="No One"; CheckType="UserRight"; SecKey="SeCreatePermanentPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.17"; Desc="Create symbolic links"; Expected="Configured"; CheckType="UserRight"; SecKey="SeCreateSymbolicLinkPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.19"; Desc="Debug programs"; Expected="Configured"; CheckType="UserRight"; SecKey="SeDebugPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.20"; Desc="Deny access from network"; Expected="Guests"; CheckType="UserRight"; SecKey="SeDenyNetworkLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.22"; Desc="Deny log on as a batch job"; Expected="Guests"; CheckType="UserRight"; SecKey="SeDenyBatchLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.23"; Desc="Deny log on as a service"; Expected="Guests"; CheckType="UserRight"; SecKey="SeDenyServiceLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.24"; Desc="Deny log on locally"; Expected="Guests"; CheckType="UserRight"; SecKey="SeDenyInteractiveLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.25"; Desc="Deny log on through RDS"; Expected="Guests"; CheckType="UserRight"; SecKey="SeDenyRemoteInteractiveLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.27"; Desc="Enable trusted for delegation"; Expected="Configured"; CheckType="UserRight"; SecKey="SeEnableDelegationPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.29"; Desc="Force shutdown from a remote system"; Expected="Configured"; CheckType="UserRight"; SecKey="SeRemoteShutdownPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.30"; Desc="Generate security audits"; Expected="Configured"; CheckType="UserRight"; SecKey="SeAuditPrivilege"; FixSids="*S-1-5-19,*S-1-5-20" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.31"; Desc="Impersonate a client after authentication"; Expected="Configured"; CheckType="UserRight"; SecKey="SeImpersonatePrivilege"; FixSids="*S-1-5-32-544,*S-1-5-19,*S-1-5-20,*S-1-5-6" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.33"; Desc="Increase scheduling priority"; Expected="Configured"; CheckType="UserRight"; SecKey="SeIncreaseBasePriorityPrivilege"; FixSids="*S-1-5-32-544,*S-1-5-90-0" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.34"; Desc="Load and unload device drivers"; Expected="Configured"; CheckType="UserRight"; SecKey="SeLoadDriverPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.35"; Desc="Lock pages in memory"; Expected="No One"; CheckType="UserRight"; SecKey="SeLockMemoryPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.36"; Desc="Log on as a batch job"; Expected="Configured"; CheckType="UserRight"; SecKey="SeBatchLogonRight"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.37"; Desc="Manage auditing and security log"; Expected="Configured"; CheckType="UserRight"; SecKey="SeSecurityPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.39"; Desc="Modify an object label"; Expected="No One"; CheckType="UserRight"; SecKey="SeRelabelPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.40"; Desc="Modify firmware environment values"; Expected="Configured"; CheckType="UserRight"; SecKey="SeSystemEnvironmentPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.41"; Desc="Perform volume maintenance tasks"; Expected="Configured"; CheckType="UserRight"; SecKey="SeManageVolumePrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.42"; Desc="Profile single process"; Expected="Configured"; CheckType="UserRight"; SecKey="SeProfileSingleProcessPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.44"; Desc="Replace a process level token"; Expected="Configured"; CheckType="UserRight"; SecKey="SeAssignPrimaryTokenPrivilege"; FixSids="*S-1-5-19,*S-1-5-20" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.45"; Desc="Restore files and directories"; Expected="Configured"; CheckType="UserRight"; SecKey="SeRestorePrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.46"; Desc="Shut down the system"; Expected="Configured"; CheckType="UserRight"; SecKey="SeShutdownPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.47"; Desc="Synchronize directory service data"; Expected="No One"; CheckType="UserRight"; SecKey="SeSyncAgentPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.2"; SubName="User Rights"; CisId="2.2.48"; Desc="Take ownership of files or other objects"; Expected="Configured"; CheckType="UserRight"; SecKey="SeTakeOwnershipPrivilege"; FixSids="*S-1-5-32-544" }

    # --- PART 2.3.1: SECURITY OPTIONS (ACCOUNTS) ---
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.3"; SubName="Sec Options"; CisId="2.3.1.1"; Desc="Ensure 'Accounts: Guest account status' is set to 'Disabled'"; Expected="False"; CheckType="GuestStatus" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.3"; SubName="Sec Options"; CisId="2.3.1.2"; Desc="Ensure 'Accounts: Limit local account use of blank passwords' is 'Enabled'"; Expected="1"; CheckType="BlankPassword" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.3"; SubName="Sec Options"; CisId="2.3.1.3"; Desc="Configure 'Accounts: Rename administrator account'"; Expected="Hardened"; CheckType="RenameAdmin" }
    [PSCustomObject]@{ GrpId="2"; GrpName="Local Policies"; SubId="2.3"; SubName="Sec Options"; CisId="2.3.1.4"; Desc="Configure 'Accounts: Rename guest account'"; Expected="Hardened"; CheckType="RenameGuest" }
)

$Results = @()
$fmt = "{0,-10} | {1,-45} | {2,-8} | {3,-15} | {4,-6}"
Write-Host ($fmt -f "CIS ID", "Policy Desc", "Expected", "Current", "Status")
Write-Host ("-" * 95)

Function Get-SecPolValue {
    param([string]$KeyName)
    $Line = $SecPol | Where-Object { $_ -match "^$KeyName\s*=" }
    if ($Line) { return ($Line -split "=")[1].Trim() }
    return "Unknown"
}

# 4. THỰC HIỆN KIỂM TRA (AUDIT LOGIC)
foreach ($Rule in $AuditRules) {
    $status = "Fail"
    $strVal = "Unknown"
    
    try {
        switch ($Rule.CheckType) {
            "History" { $strVal = Get-SecPolValue "PasswordHistorySize"; if ([int]$strVal -ge [int]$Rule.Expected) { $status = "Pass" } }
            "MaxAge" { $strVal = Get-SecPolValue "MaximumPasswordAge"; if ([int]$strVal -le [int]$Rule.Expected -and [int]$strVal -gt 0) { $status = "Pass" } }
            "MinAge" { $strVal = Get-SecPolValue "MinimumPasswordAge"; if ([int]$strVal -ge [int]$Rule.Expected) { $status = "Pass" } }
            "MinLength" { $strVal = Get-SecPolValue "MinimumPasswordLength"; if ([int]$strVal -ge [int]$Rule.Expected) { $status = "Pass" } }
            "Complexity" { $strVal = Get-SecPolValue "PasswordComplexity"; if ([int]$strVal -eq [int]$Rule.Expected) { $status = "Pass" } }
            "RelaxMinLength" { $strVal = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Control\SAM" -Name "RelaxMinimumPasswordLengthLimits" -ErrorAction SilentlyContinue; if ($null -ne $strVal -and [int]$strVal -eq [int]$Rule.Expected) { $status = "Pass" } }
            "ClearText" { $strVal = Get-SecPolValue "ClearTextPassword"; if ([int]$strVal -eq [int]$Rule.Expected) { $status = "Pass" } }
            
            "LockoutDuration" { $strVal = Get-SecPolValue "LockoutDuration"; if ([int]$strVal -ge [int]$Rule.Expected -or [int]$strVal -eq 0) { $status = "Pass" } }
            "LockoutThreshold" { $strVal = Get-SecPolValue "LockoutBadCount"; if ([int]$strVal -le [int]$Rule.Expected -and [int]$strVal -gt 0) { $status = "Pass" } }
            "AdminLockout" { $strVal = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "AllowAdministratorLockout" -ErrorAction SilentlyContinue; if ($null -ne $strVal -and [int]$strVal -eq [int]$Rule.Expected) { $status = "Pass" } }
            "LockoutWindow" { $strVal = Get-SecPolValue "ResetLockoutCount"; if ([int]$strVal -ge [int]$Rule.Expected) { $status = "Pass" } }

            "UserRight" {
                $strVal = Get-SecPolValue $Rule.SecKey
                if ($strVal -eq "Unknown" -or $strVal -eq "") { $strVal = "No One" }
                if ($Rule.Expected -eq "No One") {
                    if ($strVal -eq "No One") { $status = "Pass" }
                } else {
                    $PrimarySid = ($Rule.FixSids -split ",")[0]
                    if ($strVal -match $PrimarySid.Replace("*","\w*")) { $status = "Pass" }
                }
            }

            "GuestStatus" {
                $GuestAccount = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
                if ($GuestAccount) { $strVal = [string]$GuestAccount.Enabled } else { $strVal = "False" }
                if ($strVal -eq $Rule.Expected) { $status = "Pass" }
            }
            "BlankPassword" {
                $strVal = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -ErrorAction SilentlyContinue
                if ($null -eq $strVal) { $strVal = "1" }
                if ([string]$strVal -eq $Rule.Expected) { $status = "Pass" }
            }
            "RenameAdmin" {
                $AdminAccount = Get-LocalUser | Where-Object { $_.SID -like "S-1-5-21-*-500" }
                if ($AdminAccount) { $strVal = $AdminAccount.Name; if ($strVal -ne "Administrator") { $status = "Pass" } }
            }
            "RenameGuest" {
                $GuestAccount = Get-LocalUser | Where-Object { $_.SID -like "S-1-5-21-*-501" }
                if ($GuestAccount) { $strVal = $GuestAccount.Name; if ($strVal -ne "Guest") { $status = "Pass" } }
            }
        }
    } catch { $status = "Fail" }

    $Results += [PSCustomObject]@{
        GrpId = $Rule.GrpId; GrpName = $Rule.GrpName; SubId = $Rule.SubId; SubName = $Rule.SubName
        CisId = $Rule.CisId; Desc = $Rule.Desc; Current = $strVal; Status = $status
    }
    
    $col = if ($status -eq "Pass") { "Green" } else { "Red" }
    $dispDesc = if ($Rule.Desc.Length -gt 42) { $Rule.Desc.Substring(0,39) + "..." } else { $Rule.Desc }
    Write-Host ($fmt -f $Rule.CisId, $dispDesc, $Rule.Expected, $strVal, $status) -ForegroundColor $col
}

Remove-Item -Path $SecPolPath -Force -ErrorAction SilentlyContinue

# --- XUẤT RA JSON ---
$Results | ConvertTo-Json -Depth 4 | Out-File "$BaseDir\Reports\JSON\Identity-Audit-$TimestampFile.json" -Encoding UTF8

# --- TẠO BÁO CÁO HTML (DÙNG TEMPLATE) ---
if (-not (Test-Path $CssTemplatePath)) { throw "CSS template not found: $CssTemplatePath" }
if (-not (Test-Path $HtmlTemplatePath)) { throw "HTML template not found: $HtmlTemplatePath" }

$CssContent = Get-Content -Path $CssTemplatePath -Raw
$HtmlTemplate = Get-Content -Path $HtmlTemplatePath -Raw
$StyleBlock = "<style>`n$CssContent`n</style>"
$TableRows = New-Object System.Collections.Generic.List[string]

$TotalPass = 0; $TotalFail = 0
$Groups = $Results | Group-Object GrpId

foreach ($Grp in $Groups) {
    $GrpPass = @($Grp.Group | Where-Object { $_.Status -eq "Pass" }).Count
    $GrpFail = @($Grp.Group | Where-Object { $_.Status -eq "Fail" }).Count
    $GrpMax = [int]$Grp.Count
    $GrpPct = if($GrpMax -gt 0) { [math]::Round(($GrpPass/$GrpMax)*100) } else { 0 }
    $TotalPass += $GrpPass; $TotalFail += $GrpFail
    
    $GrpName = $Grp.Group[0].GrpName
    $clsGrp = "grp-" + $Grp.Name

    $cGrpPass = if ($GrpPass -gt 0) { "txt-pass" } else { "txt-neutral" }
    $cGrpFail = if ($GrpFail -gt 0) { "txt-fail" } else { "txt-neutral" }

    $TableRows.Add("<tr class='row-group' onclick=`"toggle('$clsGrp')`"><td class='col-desc'>$($Grp.Name) $GrpName</td><td class='col-num $cGrpPass'>$GrpPass</td><td class='col-num $cGrpFail'>$GrpFail</td><td class='col-num'>$GrpMax.0</td><td class='col-num'>$GrpPct%</td></tr>")

    $SubGroups = $Grp.Group | Group-Object SubId
    foreach ($Sub in $SubGroups) {
        $SubPass = @($Sub.Group | Where-Object { $_.Status -eq "Pass" }).Count
        $SubFail = @($Sub.Group | Where-Object { $_.Status -eq "Fail" }).Count
        $SubMax = [int]$Sub.Count
        $SubPct = if($SubMax -gt 0) { [math]::Round(($SubPass/$SubMax)*100) } else { 0 }
        $SubName = $Sub.Group[0].SubName
        $clsSub = "sub-" + $Sub.Name.Replace(".","")

        $cSubPass = if ($SubPass -gt 0) { "txt-pass" } else { "txt-neutral" }
        $cSubFail = if ($SubFail -gt 0) { "txt-fail" } else { "txt-neutral" }

        $TableRows.Add("<tr class='row-subgroup $clsGrp' style='display:none;' onclick=`"toggle('$clsSub')`"><td class='col-desc'>&nbsp;&nbsp;&nbsp;&nbsp;$($Sub.Name) $SubName</td><td class='col-num $cSubPass'>$SubPass</td><td class='col-num $cSubFail'>$SubFail</td><td class='col-num'>$SubMax.0</td><td class='col-num'>$SubPct%</td></tr>")

        foreach ($Item in $Sub.Group) {
            $iPass = if($Item.Status -eq "Pass"){1}else{0}
            $iFail = if($Item.Status -eq "Fail"){1}else{0}
            $iPct = if($iPass -eq 1){100}else{0}
            
            $cItemPass = if($iPass -eq 1){"txt-pass"}else{"txt-neutral"}
            $cItemFail = if($iFail -eq 1){"txt-fail"}else{"txt-neutral"}
            
            $TableRows.Add("<tr class='row-item $clsGrp $clsSub'><td class='col-desc' style='color:#555;'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$($Item.CisId) $($Item.Desc)</td><td class='col-num $cItemPass'>$iPass</td><td class='col-num $cItemFail'>$iFail</td><td class='col-num'>1.0</td><td class='col-num'>$iPct%</td></tr>")
        }
    }
}

$GrandMax = $TotalPass + $TotalFail
$GrandPct = if($GrandMax -gt 0) { [math]::Round(($TotalPass/$GrandMax)*100) } else { 0 }
$TableRows.Add("<tr class='footer-row'><td class='col-desc' style='text-align:right'>Total</td><td class='col-num txt-pass'>$TotalPass</td><td class='col-num txt-fail'>$TotalFail</td><td class='col-num'>$GrandMax.0</td><td class='col-num'>$GrandPct%</td></tr>")

$FinalHtml = $HtmlTemplate
$Replacements = @{
    "{{TITLE}}"        = "CIS Audit Report - Identity & Access"
    "{{STYLE_BLOCK}}"  = $StyleBlock
    "{{REPORT_TITLE}}" = "CIS Audit Report - Identity & Access Control (Full)"
    "{{DISPLAY_TIME}}" = $TimestampDisplay
    "{{OS_INFO}}"      = $OSInfo
    "{{TABLE_ROWS}}"   = ($TableRows -join [Environment]::NewLine)
}

foreach ($k in $Replacements.Keys) {
    $FinalHtml = $FinalHtml.Replace($k, $Replacements[$k])
}

$HtmlPath = "$BaseDir\Reports\HTML\Identity-Audit-$TimestampFile.html"
$FinalHtml | Out-File $HtmlPath -Encoding UTF8

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host " QUET HOAN TAT! " -ForegroundColor Green
Write-Host " [HTML Report] : $HtmlPath" -ForegroundColor Yellow
Write-Host " [JSON Data]   : $BaseDir\Reports\JSON\Identity-Audit-$TimestampFile.json" -ForegroundColor Yellow
Write-Host "===============================================================================" -ForegroundColor Cyan