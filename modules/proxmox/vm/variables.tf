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
    # No default, deliberately. This used to be optional(string, "ip=dhcp"),
    # which meant a VM whose address nobody declared silently became a DHCP
    # client. On 2026-10-07 that was one `terraform apply` away from switching
    # six already-running VMs off their static addresses, including all three
    # Kubernetes control-plane nodes and the host every agent session runs on:
    #
    #   ~ ipconfig0    = "ip=192.168.1.92/24,gw=192.168.1.1" -> "ip=dhcp"
    #   - nameserver   = "192.168.1.1" -> null
    #   - searchdomain = "home.arpa" -> null
    #
    # It read as an in-place update under "Plan: 0 to add, 0 to destroy", and
    # `var.vm_defaults` being sensitive meant the disk half of the same plan was
    # masked entirely. Forgetting an address now fails at plan time, loudly,
    # before it can reach a VM. #25 declared the six that were missing.
    ipconfig0      = string
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
