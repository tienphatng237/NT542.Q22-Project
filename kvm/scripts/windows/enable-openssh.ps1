# Run this script in an elevated PowerShell session on the GOLDEN Windows image
# before Sysprep. All cloned VMs will inherit this OpenSSH configuration.

$ErrorActionPreference = "Stop"

Write-Host "[1/5] Installing OpenSSH Server capability..."
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null

Write-Host "[2/5] Enabling and starting sshd service..."
Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd

Write-Host "[3/5] Enabling Windows Firewall inbound rule for SSH..."
if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule `
    -Name "OpenSSH-Server-In-TCP" `
    -DisplayName "OpenSSH Server (TCP-In)" `
    -Enabled True `
    -Direction Inbound `
    -Protocol TCP `
    -Action Allow `
    -LocalPort 22 | Out-Null
} else {
  Set-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -Enabled True | Out-Null
}

Write-Host "[4/5] Verifying sshd status..."
Get-Service -Name sshd | Format-Table -AutoSize

Write-Host "[5/5] Done. Recommended next step: Sysprep this image."
Write-Host 'Command: C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown /mode:vm'
