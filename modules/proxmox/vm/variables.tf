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

    # Proxmox tags. The dynamic inventory builds its Ansible groups from
    # proxmox_tags_parsed, so an untagged VM lands in no group. Stacks already
    # declared this but the module never read it, and Terraform silently drops
    # unknown attributes during object conversion, so the value was inert.
    # Existing VMs do carry tags, set by hand in Proxmox; this brings them
    # under code so they stop depending on someone remembering.
    tags = optional(string, null)

    # Optional second disk, for guests that keep bulk data off the OS disk
    # (the PBS datastore, for example), so a runaway datastore cannot wedge
    # the guest and can be grown or detached independently.
    data_disk_pool = optional(string, null)
    data_disk_size = optional(string, null)
  }))

  validation {
    condition = alltrue([
      for k, v in var.vms :
      (v.data_disk_pool == null) == (v.data_disk_size == null)
    ])
    error_message = "data_disk_pool and data_disk_size must be set together, or both omitted."
  }
}

variable "disk_backup" {
  description = "Include the VM disk in vzdump backups. Leave true unless the guest's data is reproducible from code."
  type        = bool
  default     = true
}
