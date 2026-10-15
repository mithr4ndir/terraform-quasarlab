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
    # Opt the data disk out of vzdump while the OS disk stays in. Only for
    # disks whose contents are reproducible from code or a download (model
    # weights, caches). Excluding the OS disk is never the answer: that is how
    # every backup came out green and empty (ansible-quasarlab#173).
    # Creation-only: disks is in ignore_changes, so flipping this on an existing
    # VM changes nothing. Fix the live flag with qm set if it ever has to move.
    data_disk_backup = optional(bool, true)

    # Clone by VMID instead of by template name. Names are not unique in
    # Proxmox: pve has two templates called ubuntu-24-04-cloud-init-template
    # (9000 and 9002), and a name lookup silently picks one of them.
    template_id = optional(number, null)

    # PCI passthrough. raw_id without a function suffix ("0000:0a:00") passes
    # every function of the device, which a GPU needs: they share an IOMMU
    # group. pcie = true requires machine = "q35".
    machine = optional(string, null)
    pci_devices = optional(list(object({
      raw_id = string
      pcie   = optional(bool, true)
      rombar = optional(bool, true)
    })), [])

    # Console. Clones of the ubuntu-24-04 and debian-12 templates inherit
    # vga: serial0 without a serial0 device, so there is no console at all.
    # With a GPU passed through that is worse than cosmetic: on 2026-10-15
    # llm1 sat in SeaBIOS at 100% of one vCPU with zero disk reads until
    # vga=std and serial0=socket were set, then booted in under 40s.
    # Leave both unset to keep whatever the VM has today.
    vga_type      = optional(string, null)
    serial_socket = optional(bool, false)
  }))

  validation {
    condition = alltrue([
      for k, v in var.vms :
      (v.data_disk_pool == null) == (v.data_disk_size == null)
    ])
    error_message = "data_disk_pool and data_disk_size must be set together, or both omitted."
  }

  validation {
    condition = alltrue([
      for k, v in var.vms :
      length(v.pci_devices) == 0 || !anytrue([for d in v.pci_devices : d.pcie]) || v.machine == "q35"
    ])
    error_message = "A PCI device with pcie = true needs machine = \"q35\"; the default i440fx has no PCIe bus."
  }
}

variable "disk_backup" {
  description = "Include the VM disk in vzdump backups. Leave true unless the guest's data is reproducible from code."
  type        = bool
  default     = true
}
