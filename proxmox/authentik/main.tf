terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc01"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 2.0"
    }
  }
}

provider "onepassword" {
  # Reads OP_SERVICE_ACCOUNT_TOKEN from environment
}

data "onepassword_vault" "infra" {
  name = var.op_vault
}

data "onepassword_item" "pve" {
  vault = data.onepassword_vault.infra.uuid
  title = "Proxmox API"
}

module "vms" {
  source           = "../../modules/proxmox/vm"
  proxmox_user     = data.onepassword_item.pve.username
  proxmox_password = data.onepassword_item.pve.password
  proxmox_api_url  = "https://192.168.1.11:8006/api2/json"
  pm_node          = var.pm_node
  vms              = local.vms
  sshkeys          = local.sshkeys
}
