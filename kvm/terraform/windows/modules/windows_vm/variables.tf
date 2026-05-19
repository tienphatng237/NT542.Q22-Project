variable "name" {
  description = "VM/domain name."
  type        = string
}

variable "vcpu" {
  description = "Number of virtual CPUs."
  type        = number
}

variable "memory_mb" {
  description = "Memory size in MB."
  type        = number
}

variable "disk_size_gb" {
  description = "Disk size in GB for cloned qcow2 volume."
  type        = number
}

variable "mac_address" {
  description = "Static MAC address for predictable DHCP lease mapping."
  type        = string
}

variable "addresses" {
  description = "List of IP addresses to assign statically via DHCP."
  type        = list(string)
  default     = []
}

variable "autostart" {
  description = "Whether VM should autostart with host."
  type        = bool
}

variable "pool_name" {
  description = "Libvirt storage pool name for cloned disk."
  type        = string
}

variable "network_name" {
  description = "Libvirt network name."
  type        = string
}

variable "base_volume_id" {
  description = "Base volume ID used for cloning."
  type        = string
}

variable "machine" {
  description = "QEMU machine type."
  type        = string
  default     = "pc-q35-10.0"
}

variable "disk_scsi" {
  description = "Attach OS disk with SCSI bus before XML patching."
  type        = bool
  default     = false
}

variable "wait_for_lease" {
  description = "Wait for DHCP lease during domain creation."
  type        = bool
  default     = false
}
