variable "pm_user" {
  description = "Proxmox user account"
  type        = string
  sensitive   = true
}

variable "pm_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "pm_api_url" {
  description = "Proxmox apu url"
  type        = string
  sensitive   = true  
}

variable "bastion_username" {
  description = "Bastion Username"
  type        = string
  sensitive   = true
}

variable "bastion_password" {
  description = "Bastion Password"
  type        = string
  sensitive   = true
}

variable "hostname" {
  description = "hostname to pass to new vm"
  type        = string  
}

variable "ipconfig0" {
  description = "set ip to dhcp"
  type        = string  
}
variable "sshkeys" {
  description = "sshkey public key"
  type        = string
}

variable "cloudinit_cdrom_storage" {
  default = "truenas-iscsi"
}