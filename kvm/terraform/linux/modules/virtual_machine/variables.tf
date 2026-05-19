variable "vm_user" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "network_config" {
  type    = string
  default = ""
}

variable "network_name" {
  type = string
}

variable "cloudinit_pool" {
  type    = string
  default = "default"
}

variable "wait_for_lease" {
  type    = bool
  default = true
}

variable "volume_ids" {
  type = map(string)
}

variable "nodes" {
  type = map(object({
    memory   = number
    vcpu     = number
    ip       = string
    hostname = string
    mac      = optional(string)
  }))
}
