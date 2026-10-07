terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc01"
    }
  }
}

module "vms" {
  source           = "../../modules/proxmox/vm"
  proxmox_user     = var.pm_user
  proxmox_password = var.pm_password
  proxmox_api_url  = "https://192.168.1.11:8006/api2/json"
  pm_node          = var.pm_node
  vms              = local.vms
  sshkeys          = local.sshkeys
}
