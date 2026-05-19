output "name" {
  description = "VM name."
  value       = libvirt_domain.this.name
}

output "volume_id" {
  description = "Cloned disk volume ID."
  value       = libvirt_volume.os_disk.id
}

output "ip_addresses" {
  description = "IP addresses reported by libvirt DHCP lease."
  value       = try(libvirt_domain.this.network_interface[0].addresses, [])
}

output "primary_ip" {
  description = "First known IP address, if any."
  value       = try(libvirt_domain.this.network_interface[0].addresses[0], null)
}
