locals {
  wazuh_node_name            = sort(keys(var.nodes))[0]
  wazuh_node_ip              = var.nodes[local.wazuh_node_name].ip
  ansible_log_inventory_path = abspath("${path.module}/../../../../ansible/inventories/vm/log_server.ini")

  ansible_log_inventory_content = <<-EOT
    [log_servers]
    ${local.wazuh_node_name} ansible_host=${local.wazuh_node_ip} ansible_user=${var.vm_user}
  EOT
}

resource "local_file" "ansible_log_inventory" {
  filename = local.ansible_log_inventory_path
  content  = trimspace(local.ansible_log_inventory_content)
}
