param(
    [string]$AdminAccountNewName = "",
    [string]$GuestAccountNewName = "",
    [string]$AdminAccountPassword = ""
)

function Resolve-TargetAccountName {
    param(
        [string]$ProvidedName,
        [string]$Prompt,
        [string]$DefaultName,
        [string[]]$ReservedNames = @()
    )

    $Candidate = $ProvidedName

    if ([string]::IsNullOrWhiteSpace($Candidate) -and [Environment]::UserInteractive) {
        while ([string]::IsNullOrWhiteSpace($Candidate)) {
            $Candidate = Read-Host $Prompt
        }
    }

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        throw "Missing required account name for '$DefaultName'. Provide it as a script parameter."
    }

    $Candidate = $Candidate.Trim()

    if ($Candidate -match '[\\/:*?"<>|]') {
        throw "Account name '$Candidate' contains invalid characters."
    }

    if ($Candidate.Equals($DefaultName, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Account name '$Candidate' must differ from the default name '$DefaultName'."
    }

    foreach ($ReservedName in $ReservedNames) {
        if (-not [string]::IsNullOrWhiteSpace($ReservedName) -and $Candidate.Equals($ReservedName, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Account name '$Candidate' conflicts with reserved name '$ReservedName'."
        }
    }

    return $Candidate
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "VUI LONG CHAY SCRIPT NAY BANG QUYEN ADMINISTRATOR (Run as Administrator)!"
    Start-Sleep -Seconds 5
    exit
}

$BaseDir = "C:\CIS-Automation"
if (-not (Test-Path "$BaseDir\Logs")) { New-Item -ItemType Directory -Force -Path "$BaseDir\Logs" | Out-Null }

$StartTime = Get-Date
$TimestampFile = $StartTime.ToString("yyyyMMdd_HHmmss")
$TimestampDisplay = $StartTime.ToString("dd/MM/yyyy HH:mm:ss")
$LogFile = "$BaseDir\Logs\Identity-Remediation-$TimestampFile.log"

$NewAdminName = Resolve-TargetAccountName -ProvidedName $AdminAccountNewName -Prompt "Nhap ten moi cho tai khoan Administrator (Khong duoc de trong)" -DefaultName "Administrator" -ReservedNames @("Guest", "Guest_Hardened")
$NewGuestName = Resolve-TargetAccountName -ProvidedName $GuestAccountNewName -Prompt "Nhap ten moi cho tai khoan Guest (Khong duoc de trong)" -DefaultName "Guest" -ReservedNames @("Administrator", $NewAdminName)

if (-not [string]::IsNullOrWhiteSpace($AdminAccountPassword)) {
    try {
        $SecureAdminPassword = ConvertTo-SecureString -String $AdminAccountPassword -AsPlainText -Force
    } catch {
        throw "Khong the chuyen doi mat khau quan tri duoc quan ly sang SecureString. $($_.Exception.Message)"
    }
}

Start-Transcript -Path $LogFile -Force

Clear-Host
Write-Host "===============================================================================" -ForegroundColor Green
Write-Host " BAT DAU KHAC PHUC (REMEDIATION) THEO CHUAN CIS BENCHMARK V5.0.0" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host " Module            : Identity & Access Control" -ForegroundColor Green
Write-Host " Thoi gian bat dau : $TimestampDisplay" -ForegroundColor Green
Write-Host "===============================================================================`n" -ForegroundColor Green

$IdentityRules = @(
    # Part 1.1 & 1.2
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.1.1"; CheckType="History" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.1.2"; CheckType="MaxAge" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.1.3"; CheckType="MinAge" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.1.4"; CheckType="MinLength" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.1.5"; CheckType="Complexity" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.1.6"; CheckType="RelaxMinLength" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.1.7"; CheckType="ClearText" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.2.1"; CheckType="LockoutDuration" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.2.2"; CheckType="LockoutThreshold" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.2.3"; CheckType="AdminLockout" }
    [PSCustomObject]@{ GrpName="Account Policies"; CisId="1.2.4"; CheckType="LockoutWindow" }

    # Part 2.2 User Rights Assignment
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.1";  CheckType="UserRight"; SecKey="SeTrustedCredManAccessPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.2";  CheckType="UserRight"; SecKey="SeNetworkLogonRight"; FixSids="*S-1-5-32-544,*S-1-5-11" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.4";  CheckType="UserRight"; SecKey="SeTcbPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.5";  CheckType="UserRight"; SecKey="SeMachineAccountPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.6";  CheckType="UserRight"; SecKey="SeIncreaseQuotaPrivilege"; FixSids="*S-1-5-32-544,*S-1-5-19,*S-1-5-20" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.7";  CheckType="UserRight"; SecKey="SeInteractiveLogonRight"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.9";  CheckType="UserRight"; SecKey="SeRemoteInteractiveLogonRight"; FixSids="*S-1-5-32-544,*S-1-5-32-555" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.11"; CheckType="UserRight"; SecKey="SeBackupPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.12"; CheckType="UserRight"; SecKey="SeSystemtimePrivilege"; FixSids="*S-1-5-32-544,*S-1-5-19" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.13"; CheckType="UserRight"; SecKey="SeCreatePagefilePrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.14"; CheckType="UserRight"; SecKey="SeCreateTokenPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.15"; CheckType="UserRight"; SecKey="SeCreateGlobalPrivilege"; FixSids="*S-1-5-32-544,*S-1-5-19,*S-1-5-20,*S-1-5-6" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.16"; CheckType="UserRight"; SecKey="SeCreatePermanentPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.17"; CheckType="UserRight"; SecKey="SeCreateSymbolicLinkPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.19"; CheckType="UserRight"; SecKey="SeDebugPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.20"; CheckType="UserRight"; SecKey="SeDenyNetworkLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.22"; CheckType="UserRight"; SecKey="SeDenyBatchLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.23"; CheckType="UserRight"; SecKey="SeDenyServiceLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.24"; CheckType="UserRight"; SecKey="SeDenyInteractiveLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.25"; CheckType="UserRight"; SecKey="SeDenyRemoteInteractiveLogonRight"; FixSids="*S-1-5-32-546" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.27"; CheckType="UserRight"; SecKey="SeEnableDelegationPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.29"; CheckType="UserRight"; SecKey="SeRemoteShutdownPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.30"; CheckType="UserRight"; SecKey="SeAuditPrivilege"; FixSids="*S-1-5-19,*S-1-5-20" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.31"; CheckType="UserRight"; SecKey="SeImpersonatePrivilege"; FixSids="*S-1-5-32-544,*S-1-5-19,*S-1-5-20,*S-1-5-6" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.33"; CheckType="UserRight"; SecKey="SeIncreaseBasePriorityPrivilege"; FixSids="*S-1-5-32-544,*S-1-5-90-0" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.34"; CheckType="UserRight"; SecKey="SeLoadDriverPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.35"; CheckType="UserRight"; SecKey="SeLockMemoryPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.36"; CheckType="UserRight"; SecKey="SeBatchLogonRight"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.37"; CheckType="UserRight"; SecKey="SeSecurityPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.39"; CheckType="UserRight"; SecKey="SeRelabelPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.40"; CheckType="UserRight"; SecKey="SeSystemEnvironmentPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.41"; CheckType="UserRight"; SecKey="SeManageVolumePrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.42"; CheckType="UserRight"; SecKey="SeProfileSingleProcessPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.44"; CheckType="UserRight"; SecKey="SeAssignPrimaryTokenPrivilege"; FixSids="*S-1-5-19,*S-1-5-20" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.45"; CheckType="UserRight"; SecKey="SeRestorePrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.46"; CheckType="UserRight"; SecKey="SeShutdownPrivilege"; FixSids="*S-1-5-32-544" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.47"; CheckType="UserRight"; SecKey="SeSyncAgentPrivilege"; FixSids="" }
    [PSCustomObject]@{ GrpName="User Rights Assignment"; CisId="2.2.48"; CheckType="UserRight"; SecKey="SeTakeOwnershipPrivilege"; FixSids="*S-1-5-32-544" }

    # Part 2.3.1 Security Options
    [PSCustomObject]@{ GrpName="Local Policies"; CisId="2.3.1.1"; CheckType="GuestStatus" }
    [PSCustomObject]@{ GrpName="Local Policies"; CisId="2.3.1.2"; CheckType="BlankPassword" }
    [PSCustomObject]@{ GrpName="Local Policies"; CisId="2.3.1.3"; CheckType="RenameAdmin" }
    [PSCustomObject]@{ GrpName="Local Policies"; CisId="2.3.1.4"; CheckType="RenameGuest" }
)

Function Set-LocalSecurityPolicy {
    param([string]$Setting, [string]$Value)
    $InfPath = "$env:TEMP\secpol_fix.inf"
    "[Unicode]`r`nUnicode=yes`r`n[System Access]`r`n$Setting = $Value" | Out-File -FilePath $InfPath -Encoding ASCII
    secedit /configure /db $env:windir\security\local.sdb /cfg $InfPath /areas SECURITYPOLICY | Out-Null
    Remove-Item -Path $InfPath -Force -ErrorAction SilentlyContinue
}

Function Set-UserRightPolicy {
    param([string]$Privilege, [string]$Accounts)
    $InfPath = "$env:TEMP\ur_fix.inf"
    "[Unicode]`r`nUnicode=yes`r`n[Privilege Rights]`r`n$Privilege = $Accounts" | Out-File -FilePath $InfPath -Encoding ASCII
    secedit /configure /db $env:windir\security\local.sdb /cfg $InfPath /areas USER_RIGHTS | Out-Null
    Remove-Item -Path $InfPath -Force -ErrorAction SilentlyContinue
}

$GroupedRules = $IdentityRules | Group-Object GrpName

foreach ($Group in $GroupedRules) {
    Write-Host "`n>> $($Group.Name)" -ForegroundColor Yellow
    
    foreach ($Rule in $Group.Group) {
        try {
            $TimeNow = Get-Date -Format "HH:mm:ss"
            
            switch ($Rule.CheckType) {
                "History" { net accounts /uniquepw:24 | Out-Null; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Enforce password history = 24" -ForegroundColor Green }
                "MaxAge" { net accounts /maxpwage:365 | Out-Null; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Maximum password age = 365" -ForegroundColor Green }
                "MinAge" { net accounts /minpwage:1 | Out-Null; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Minimum password age = 1" -ForegroundColor Green }
                "MinLength" { net accounts /minpwlen:14 | Out-Null; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Minimum password length = 14" -ForegroundColor Green }
                "Complexity" { Set-LocalSecurityPolicy -Setting "PasswordComplexity" -Value 1; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Bật Password Complexity" -ForegroundColor Green }
                "RelaxMinLength" { Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\SAM" -Name "RelaxMinimumPasswordLengthLimits" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Bật Relax minimum password length limits" -ForegroundColor Green }
                "ClearText" { Set-LocalSecurityPolicy -Setting "ClearTextPassword" -Value 0; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Tắt Reversible encryption" -ForegroundColor Green }
                
                "LockoutDuration" { net accounts /lockoutduration:15 | Out-Null; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Account lockout duration = 15" -ForegroundColor Green }
                "LockoutThreshold" { net accounts /lockoutthreshold:5 | Out-Null; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Account lockout threshold = 5" -ForegroundColor Green }
                "AdminLockout" { Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "AllowAdministratorLockout" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Bật Allow Administrator account lockout" -ForegroundColor Green }
                "LockoutWindow" { net accounts /lockoutwindow:15 | Out-Null; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Reset account lockout counter = 15" -ForegroundColor Green }

                "UserRight" {
                    Set-UserRightPolicy -Privilege $Rule.SecKey -Accounts $Rule.FixSids
                    Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Cấu hình Quyền $($Rule.SecKey)" -ForegroundColor Green
                }

                "GuestStatus" { Disable-LocalUser -Name "Guest" -ErrorAction SilentlyContinue; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Vô hiệu hóa tài khoản Guest" -ForegroundColor Green }
                "BlankPassword" { Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 1 -Type DWord -Force; Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Bật Limit local account use of blank passwords" -ForegroundColor Green }
                
                "RenameAdmin" {
                    <#
                    $AdminAccount = Get-LocalUser | Where-Object { $_.SID -like "S-1-5-21-*-500" }
                    $ManagedAdminName = $AdminAccount.Name

                    if ($AdminAccount.Name -eq "Administrator") {
                        Rename-LocalUser -Name "Administrator" -NewName $NewAdminName
                        $ManagedAdminName = $NewAdminName
                        Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Đã đổi tên Administrator thành '$NewAdminName'" -ForegroundColor Green
                    } else {
                        Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Tài khoản Administrator (SID 500) đã mang tên khác mặc định" -ForegroundColor Green
                    }

                    if (-not [string]::IsNullOrWhiteSpace($AdminAccountPassword)) {
                        Set-LocalUser -Name $ManagedAdminName -Password $SecureAdminPassword
                        Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Đã đặt mật khẩu quản trị đạt chuẩn cho '$ManagedAdminName'" -ForegroundColor Green
                    } else {
                        Write-Host "[$TimeNow] [ WARN ] $($Rule.CisId) -> Chưa cấu hình mật khẩu quản trị được quản lý; giữ nguyên mật khẩu hiện tại" -ForegroundColor Yellow
                    }
                    #>
                    Write-Host "[$TimeNow] [ SKIP ] $($Rule.CisId) -> Tam thoi comment logic doi ten/doi mat khau Administrator de on dinh WinRM." -ForegroundColor Yellow
                }
                "RenameGuest" {
                    <#
                    $GuestAccount = Get-LocalUser | Where-Object { $_.SID -like "S-1-5-21-*-501" }
                    if ($GuestAccount.Name -eq "Guest") {
                        Rename-LocalUser -Name "Guest" -NewName $NewGuestName
                        Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Đã đổi tên Guest thành '$NewGuestName'" -ForegroundColor Green
                    } else { Write-Host "[$TimeNow] [ PASS ] $($Rule.CisId) -> Tài khoản Guest (SID 501) đã mang tên khác mặc định" -ForegroundColor Green }
                    #>
                    Write-Host "[$TimeNow] [ SKIP ] $($Rule.CisId) -> Tam thoi comment logic doi ten Guest." -ForegroundColor Yellow
                }
            }
        } catch {
            $TimeNow = Get-Date -Format "HH:mm:ss"
            Write-Host "[$TimeNow] [ FAIL ] Lỗi tại $($Rule.CisId): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n[+] Dang ap dung chinh sach Group Policy (gpupdate) xuong he thong..." -ForegroundColor Cyan
gpupdate /force /wait:0 | Out-Null

Write-Host "`n===============================================================================" -ForegroundColor Green
Write-Host " HOAN TAT KHAC PHUC VA DA CHAY GPUPDATE TUDONG!" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Green

Stop-Transcript
