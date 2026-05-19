resource "libvirt_network" "this" {
  name      = var.name
  mode      = "nat"
  domain    = var.domain
  addresses = var.cidr
  bridge    = var.bridge_name
  autostart = true

  dhcp {
    enabled = true
  }

  dns {
    enabled = true

    dynamic "hosts" {
      for_each = var.hosts
      content {
        ip       = hosts.value
        hostname = hosts.key
      }
    }
  }
}
