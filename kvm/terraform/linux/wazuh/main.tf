locals {
  primary_node      = one(values(var.nodes))
  dns_servers_yaml  = join("\n        - ", var.network_dns_servers)
}

module "volume" {
  source     = "../modules/volume"
  base_image = var.base_image
  base_name  = "ubuntu-22.04-wazuh-base"
  base_pool  = var.base_pool
  disk_pool  = var.storage_pool

  disks = {
    for k, v in var.nodes : k => v.disk_gb
  }
}

module "vm" {
  source = "../modules/virtual_machine"

  vm_user        = var.vm_user
  ssh_public_key = var.ssh_public_key
  network_name   = var.network_name
  cloudinit_pool = var.cloudinit_pool
  wait_for_lease = false
  network_config = <<-EOF_NETWORK
version: 2
ethernets:
  ens3:
    dhcp4: false
    addresses:
      - ${local.primary_node.ip}/${var.network_prefix_length}
    routes:
      - to: default
        via: ${var.network_gateway}
    nameservers:
      addresses:
        - ${local.dns_servers_yaml}
EOF_NETWORK
  volume_ids     = module.volume.volume_ids
  nodes          = var.nodes
}
