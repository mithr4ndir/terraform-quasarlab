terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc01"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "bastion" {
  name         = var.hostname
  target_node  = "pve"
  clone        = "ubuntu-24-04-cloud-init-template"
  full_clone   = true
  onboot       = true
  memory       = 8192
  scsihw       = "virtio-scsi-single"
  boot         = "order=scsi0"
  bootdisk     = "scsi0"
  vm_state     = "running"
  agent        = 1
  ipconfig0    = var.ipconfig0
  sshkeys      = var.sshkeys
  ciuser       = var.bastion_username
  cipassword   = var.bastion_password
  skip_ipv6    = true
  hotplug      = "network,disk,usb,memory,cpu"

  cpu {
    cores   = 4
    type    = "host"
    numa    = true
    sockets = 1
  }

  disk {
    type = "ignore"
    slot = "scsi0"
  }

  disk {
    type = "ignore"
    slot = "ide2"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    id     = 0
  }
}