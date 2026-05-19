# Windows Golden Image Prep

## Enable OpenSSH once on golden image

Open an elevated PowerShell on the golden Windows VM and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\path\to\enable-openssh.ps1"
```

## Install newer Administrative Templates (ADMX)

To expose newer Microsoft Defender policies in `gpedit.msc`, run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\path\to\install-admx-templates.ps1"
```

This script downloads the official Windows 11 24H2 ADMX package from Microsoft,
backs up `C:\Windows\PolicyDefinitions`, and copies the new `.admx/.adml` files
into the local policy store.

Then run Sysprep:

```powershell
C:\Windows\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown /mode:vm
```

After this, Terraform clones from the golden image will boot with `sshd` enabled.
