variable "name" {
  description = "Libvirt network name."
  type        = string
}

variable "mode" {
  description = "Libvirt network mode."
  type        = string
  default     = "nat"
}

variable "addresses" {
  description = "List of network CIDRs in libvirt address syntax."
  type        = list(string)
}

variable "autostart" {
  description = "Whether the network should autostart with libvirt."
  type        = bool
  default     = true
}
