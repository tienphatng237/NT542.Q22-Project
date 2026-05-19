variable "vm_user" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "base_image" {
  type = string
}

variable "storage_pool" {
  type    = string
  default = "kvm"
}

variable "base_pool" {
  type    = string
  default = "kvm"
}

variable "cloudinit_pool" {
  type    = string
  default = "kvm"
}

variable "network_name" {
  type = string
}

variable "network_gateway" {
  type    = string
  default = "192.168.250.1"
}

variable "network_prefix_length" {
  type    = number
  default = 24
}

variable "network_dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

variable "nodes" {
  type = map(object({
    memory   = number
    vcpu     = number
    ip       = string
    hostname = string
    disk_gb  = number
  }))
}
