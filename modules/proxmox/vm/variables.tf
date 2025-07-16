variable "pm_node" {
  type = string
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_user" {
  type = string
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}
variable "sshkeys" {
  type = string
}
variable "vms" {
  type = map(object({
    template        = string
    username        = string
    password        = string
    memory          = number
    cores           = number
    sockets         = number
    storage_pool    = string
    network_bridge  = string
    skip_ipv6       = bool
    onboot          = bool
    full_clone      = bool
    hotplug         = string
  }))
}
