output "golden_base_volume_id" {
  description = "Imported golden volume ID in libvirt pool."
  value       = libvirt_volume.golden_base.id
}

output "network" {
  description = "Libvirt network information for the lab."
  value = {
    name = module.network.name
    id   = module.network.id
  }
}

output "domain_controller" {
  description = "Domain Controller runtime information."
  value = {
    name       = module.domain_controller.name
    volume_id  = module.domain_controller.volume_id
    ip_address = module.domain_controller.primary_ip
    ip_list    = module.domain_controller.ip_addresses
  }
}

output "member_server" {
  description = "Member Server runtime information."
  value = {
    name       = module.member_server.name
    volume_id  = module.member_server.volume_id
    ip_address = module.member_server.primary_ip
    ip_list    = module.member_server.ip_addresses
  }
}

output "file_server" {
  description = "File Server runtime information."
  value = {
    name       = module.file_server.name
    volume_id  = module.file_server.volume_id
    ip_address = module.file_server.primary_ip
    ip_list    = module.file_server.ip_addresses
  }
}
