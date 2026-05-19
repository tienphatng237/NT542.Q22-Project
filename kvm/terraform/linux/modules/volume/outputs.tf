output "volume_ids" {
  value = {
    for k, v in libvirt_volume.disk : k => v.id
  }
}
