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
    template       = string
    username       = string
    password       = string
    memory         = number
    cores          = number
    sockets        = number
    storage_pool   = string
    storage_size   = string
    network_bridge = string
    skip_ipv6      = bool
    onboot         = bool
    full_clone     = bool
    hotplug        = string
    ipconfig0      = optional(string, "ip=dhcp")
    # Which PVE node this VM runs on. Omit to use var.pm_node for every VM in
    # the map, which only works while they all live on the same node: the
    # kubernetes module has k8cluster1 on pve and k8cluster2/3 on pve2, and
    # could not express that at all before this existed.
    target_node = optional(string)
  }))
}

variable "disk_backup" {
  description = "Include the VM disk in vzdump backups. Leave true unless the guest's data is reproducible from code."
  type        = bool
  default     = true
}
