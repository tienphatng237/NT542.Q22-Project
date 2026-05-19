output "name" {
  description = "Libvirt network name."
  value       = libvirt_network.this.name
}

output "id" {
  description = "Libvirt network ID."
  value       = libvirt_network.this.id
}
