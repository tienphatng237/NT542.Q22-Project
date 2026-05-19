resource "libvirt_volume" "base" {
  source = var.base_image
  name   = var.base_name
  pool   = var.base_pool
}

resource "libvirt_volume" "disk" {
  for_each       = var.disks
  name           = "${each.key}.qcow2"
  pool           = var.disk_pool
  base_volume_id = libvirt_volume.base.id
  size           = each.value * 1024 * 1024 * 1024
}
