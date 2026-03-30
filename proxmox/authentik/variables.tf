variable "pm_node" {
  type    = string
  default = "pve"
}

variable "op_vault" {
  description = "1Password vault name for credential lookups"
  type        = string
  default     = "Infrastructure"
}

variable "vm_defaults" {
  description = "Default values for VM deployment"
  type = object({
    storage_pool   = string
    storage_size   = string
    network_bridge = string
  })

  default = {
    storage_pool   = "truenas-iscsi"
    storage_size   = "54784M"
    network_bridge = "vmbr0"
  }
}
