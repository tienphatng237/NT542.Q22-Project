resource "libvirt_cloudinit_disk" "this" {
  for_each = var.nodes

  name = "cloudinit-${each.key}.iso"
  pool = var.cloudinit_pool

  network_config = var.network_config

  user_data = <<EOF_USER_DATA
#cloud-config
hostname: ${each.value.hostname}
users:
  - name: ${var.vm_user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys:
      - ${file(var.ssh_public_key)}
EOF_USER_DATA
}

resource "libvirt_domain" "this" {
  for_each = var.nodes

  name   = each.value.hostname
  memory = each.value.memory
  vcpu   = each.value.vcpu

  disk {
    volume_id = var.volume_ids[each.key]
  }

  cloudinit = libvirt_cloudinit_disk.this[each.key].id

  network_interface {
    network_name   = var.network_name
    addresses      = [each.value.ip]
    mac            = each.value.mac
    wait_for_lease = var.wait_for_lease
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
  }
}
