locals {
  ansible_kvm_inventory_path = abspath("${path.module}/../../ansible/inventories/kvm/kvm.ini")

  ansible_kvm_inventory_content = <<-EOT
    [windows]
    ${module.domain_controller.name} ansible_host=${module.domain_controller.primary_ip}
    ${module.member_server.name} ansible_host=${module.member_server.primary_ip}
    ${module.file_server.name} ansible_host=${module.file_server.primary_ip}

    [domain_controllers]
    ${module.domain_controller.name}

    [member_servers]
    ${module.member_server.name}
    ${module.file_server.name}

    [file_servers]
    ${module.file_server.name}
  EOT
}

resource "local_file" "ansible_kvm_inventory" {
  filename = local.ansible_kvm_inventory_path
  content  = trimspace(local.ansible_kvm_inventory_content)
}
