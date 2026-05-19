# KVM Terraform Stack (Windows DC + Member)

This stack creates two Windows Server VMs on local KVM/libvirt by cloning from a sysprepped golden image.

## What It Creates

- 1 imported base volume from `win2k22-golden.qcow2`
- 1 VM as Domain Controller (`dc01`)
- 1 VM as Member Server (`member01`)
- cloned qcow2 disks in the selected libvirt pool

The module pins a Windows-friendly hardware profile for clones:

- machine type `pc-q35-10.0`
- disk bus via SCSI (avoids default virtio-disk mismatch from some golden images)
- `wait_for_lease = false` to avoid long Terraform hangs when Windows DHCP is delayed
- video model `qxl` with extra VRAM injected through the XML patch for higher desktop resolutions over SPICE

## Prerequisites

- A sysprepped golden image already exists at:
  - `kvm/iso/win2k22-golden.qcow2`
- Libvirt pool exists (default value uses `default`)
- This stack creates its own isolated libvirt NAT network for the lab
- You can connect to `qemu:///system` with `virsh`

## Usage

```bash
cd kvm/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

After apply, check IP outputs:

```bash
terraform output
```

This stack also generates an Ansible inventory file at:

- `ansible/inventories/kvm/kvm.ini`

## Notes

- If a VM with the same name already exists (for example manual `member01`), rename or remove it before apply.
- Changing the golden qcow2 alone does not affect libvirt display hardware; the domain XML in this module controls the video device.
- This Terraform stack handles infrastructure cloning only.
- Guest OS configuration (hostname inside Windows, static IP, AD promotion, domain join, CIS hardening) should be done with Ansible/PowerShell after VM creation.
