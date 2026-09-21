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

    # Proxmox tags. The dynamic inventory builds its groups from
    # proxmox_tags_parsed, so a VM with no tags lands in no Ansible group at
    # all. Every stack already declared this, but the module never consumed it
    # and Terraform silently drops unknown attributes during object conversion,
    # so no Terraform-managed VM has ever been tagged (ansible-quasarlab#192).
    tags = optional(string, null)

    # Place this VM on a specific node. Defaults to var.pm_node so existing
    # stacks are unaffected. Needed when one stack spans both cluster members.
    target_node = optional(string, null)

    # Optional second disk, for guests that keep bulk data separate from the
    # OS disk (PBS datastore, for example). Both must be set together.
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
