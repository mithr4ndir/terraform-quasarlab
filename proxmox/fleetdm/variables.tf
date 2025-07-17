variable "pm_user" {
  type = string
}

variable "pm_password" {
  type      = string
  sensitive = true
}

variable "pm_api_url" {
  type = string
}

variable "pm_node" {
  type = string
}

variable "sshkeys" {
  type = string
}

variable "vm_defaults" {
  description = "Default values for VM deployment"
  type = object({
    username        = string
    password        = string
    storage_pool    = string
    network_bridge  = string
  })

  default = {
    username        = "ubuntu"
    password        = "changeme"
    storage_pool    = "truenas-iscsi"
    network_bridge  = "vmbr0"
  }
}