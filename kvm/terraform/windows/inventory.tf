locals {
  ansible_vm_inventory_path = abspath("${path.module}/../../../ansible/inventories/vm/windows.ini")

  ansible_vm_inventory_content = <<-EOT
    [windows]
    ${module.domain_controller.name} ansible_host=${module.domain_controller.primary_ip} hardeningkitty_profile=dc
    ${module.member_server.name} ansible_host=${module.member_server.primary_ip} hardeningkitty_profile=member
    ${module.file_server.name} ansible_host=${module.file_server.primary_ip} hardeningkitty_profile=member

    [domain_controllers]
    ${module.domain_controller.name}

    [member_servers]
    ${module.member_server.name}
    ${module.file_server.name}

    [file_servers]
    ${module.file_server.name}
  EOT
}

resource "local_file" "ansible_vm_inventory" {
  filename = local.ansible_vm_inventory_path
  content  = trimspace(local.ansible_vm_inventory_content)
}
