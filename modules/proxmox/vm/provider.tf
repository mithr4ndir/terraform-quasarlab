terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.2-rc01"
    }
    local = {
      source = "hashicorp/local"
      version = "2.5.3"
    }
  }
}