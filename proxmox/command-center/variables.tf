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

variable "vm_defaults" {
  type = object({
    sshkeys         = string
    username        = string
    password        = string
    storage_pool    = string
    network_bridge  = string
  })
}
