terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

resource "libvirt_network" "this" {
  name      = var.name
  mode      = var.mode
  autostart = var.autostart
  addresses = var.addresses
}
