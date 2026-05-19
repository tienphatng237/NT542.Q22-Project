terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

resource "libvirt_volume" "os_disk" {
  name           = "${var.name}.qcow2"
  pool           = var.pool_name
  base_volume_id = var.base_volume_id
  size           = var.disk_size_gb * 1024 * 1024 * 1024
  format         = "qcow2"
}

resource "libvirt_domain" "this" {
  name      = var.name
  type      = "kvm"
  machine   = var.machine
  memory    = var.memory_mb
  vcpu      = var.vcpu
  autostart = var.autostart

  disk {
    volume_id = libvirt_volume.os_disk.id
    scsi      = var.disk_scsi
  }

  network_interface {
    network_name   = var.network_name
    mac            = var.mac_address
    addresses      = var.addresses
    wait_for_lease = var.wait_for_lease
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  # Windows Server clones need a modern virtual GPU for higher resolutions.
  # QXL works well with SPICE and avoids libvirt falling back to cirrus.
  video {
    type = "qxl"
  }

  # dmacvicar/libvirt v0.8.x does not expose SATA disk bus directly in HCL.
  # We patch generated domain XML so cloned Windows boots with the same
  # storage/network profile as the source golden VM.
  xml {
    xslt = file("${path.module}/windows-compat.xslt")
  }
}
