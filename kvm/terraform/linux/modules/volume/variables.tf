variable "base_image" {
  type = string
}

variable "base_name" {
  type = string
}

variable "base_pool" {
  type    = string
  default = "default"
}

variable "disk_pool" {
  type    = string
  default = "default"
}

variable "disks" {
  type = map(number) # GB
}
