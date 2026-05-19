variable "libvirt_uri" {
  description = "Libvirt connection URI."
  type        = string
}

variable "pool_name" {
  description = "Libvirt storage pool where imported base image and cloned disks are stored."
  type        = string
}

variable "network" {
  description = "Libvirt network configuration for the isolated Windows lab."
  type = object({
    name      = string
    mode      = string
    cidr      = string
    autostart = bool
  })
}

variable "golden_image_path" {
  description = "Path to the sysprepped golden qcow2 image on the host."
  type        = string
}

variable "golden_volume_name" {
  description = "Name of the imported base image volume in the libvirt pool."
  type        = string
}

variable "domain_controller" {
  description = "Domain Controller VM settings."
  type = object({
    name           = string
    vcpu           = number
    memory_mb      = number
    disk_size_gb   = number
    mac_address    = string
    ip_addresses   = list(string)
    machine_type   = string
    disk_scsi      = bool
    wait_for_lease = bool
    autostart      = bool
  })
}

variable "member_server" {
  description = "Member Server VM settings."
  type = object({
    name           = string
    vcpu           = number
    memory_mb      = number
    disk_size_gb   = number
    mac_address    = string
    ip_addresses   = list(string)
    machine_type   = string
    disk_scsi      = bool
    wait_for_lease = bool
    autostart      = bool
  })
}

variable "file_server" {
  description = "File Server VM settings."
  type = object({
    name           = string
    vcpu           = number
    memory_mb      = number
    disk_size_gb   = number
    mac_address    = string
    ip_addresses   = list(string)
    machine_type   = string
    disk_scsi      = bool
    wait_for_lease = bool
    autostart      = bool
  })
}
