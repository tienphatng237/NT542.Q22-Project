output "ips" {
  value = {
    for k, v in libvirt_domain.this :
    k => try(v.network_interface[0].addresses[0], var.nodes[k].ip)
  }
}
