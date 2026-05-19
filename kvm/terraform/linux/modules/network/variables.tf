variable "name" {
  type = string
}

variable "cidr" {
  type = list(string)
}

variable "domain" {
  type    = string
  default = "lab.local"
}

variable "hosts" {
  type = map(string)
}

variable "bridge_name" {
  type    = string
  default = null
}
