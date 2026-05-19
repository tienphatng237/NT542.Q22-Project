locals {
  golden_image_abspath = abspath("${path.module}/${var.golden_image_path}")
}

module "network" {
  source = "./modules/network"

  name      = var.network.name
  mode      = var.network.mode
  addresses = [var.network.cidr]
  autostart = var.network.autostart
}

resource "libvirt_volume" "golden_base" {
  name   = var.golden_volume_name
  pool   = var.pool_name
  source = local.golden_image_abspath
  format = "qcow2"

  # Avoid needless replacement when the same file is addressed via different
  # host path representations (for example /home/... symlink vs /vm-storage/...).
  lifecycle {
    ignore_changes = [source]
  }
}

module "domain_controller" {
  source = "./modules/windows_vm"

  name           = var.domain_controller.name
  vcpu           = var.domain_controller.vcpu
  memory_mb      = var.domain_controller.memory_mb
  disk_size_gb   = var.domain_controller.disk_size_gb
  mac_address    = var.domain_controller.mac_address
  addresses      = var.domain_controller.ip_addresses
  autostart      = var.domain_controller.autostart
  pool_name      = var.pool_name
  network_name   = module.network.name
  base_volume_id = libvirt_volume.golden_base.id
  machine        = var.domain_controller.machine_type
  disk_scsi      = var.domain_controller.disk_scsi
  wait_for_lease = var.domain_controller.wait_for_lease
}

module "member_server" {
  source = "./modules/windows_vm"

  name           = var.member_server.name
  vcpu           = var.member_server.vcpu
  memory_mb      = var.member_server.memory_mb
  disk_size_gb   = var.member_server.disk_size_gb
  mac_address    = var.member_server.mac_address
  addresses      = var.member_server.ip_addresses
  autostart      = var.member_server.autostart
  pool_name      = var.pool_name
  network_name   = module.network.name
  base_volume_id = libvirt_volume.golden_base.id
  machine        = var.member_server.machine_type
  disk_scsi      = var.member_server.disk_scsi
  wait_for_lease = var.member_server.wait_for_lease
}

module "file_server" {
  source = "./modules/windows_vm"

  name           = var.file_server.name
  vcpu           = var.file_server.vcpu
  memory_mb      = var.file_server.memory_mb
  disk_size_gb   = var.file_server.disk_size_gb
  mac_address    = var.file_server.mac_address
  addresses      = var.file_server.ip_addresses
  autostart      = var.file_server.autostart
  pool_name      = var.pool_name
  network_name   = module.network.name
  base_volume_id = libvirt_volume.golden_base.id
  machine        = var.file_server.machine_type
  disk_scsi      = var.file_server.disk_scsi
  wait_for_lease = var.file_server.wait_for_lease
}
