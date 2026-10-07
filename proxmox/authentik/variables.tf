variable "pm_node" {
  type    = string
  default = "pve"
}

# Credentials below are supplied as TF_VAR_* environment variables by
# scripts/tf-cached-secrets.sh from the ansible-quasarlab 1Password file
# cache. Never put them in a committed file.
variable "pm_user" {
  type      = string
  sensitive = true
}

variable "pm_password" {
  type      = string
  sensitive = true
}

variable "ci_username" {
  type      = string
  sensitive = true
}

variable "ci_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
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
