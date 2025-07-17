provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_parallel     = 5
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "this" {
  for_each = var.vms

  name            = each.key
  target_node     = var.pm_node
  agent           = 1
  clone           = each.value.template
  full_clone      = each.value.full_clone
  onboot          = each.value.onboot
  memory          = each.value.memory
  hotplug         = each.value.hotplug
  skip_ipv6       = each.value.skip_ipv6
  scsihw          = "virtio-scsi-single"
  ciuser          = each.value.username
  cipassword      = each.value.password
  ciupgrade       = true
  sshkeys         = var.sshkeys
  ipconfig0       = "ip=dhcp"
  bootdisk        = "scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          storage    = each.value.storage_pool
          size       = each.value.storage_size
          asyncio    = "io_uring"
          cache      = "writeback"
          discard    = true
          iothread   = true
          backup     = false
          emulatessd = true
        }
      }
    }
    ide {
      ide2 {
        ignore = true
      }
    }
  }

  cpu { 
    cores          = each.value.cores
    sockets        = each.value.sockets
    numa           = true
    type           = "host"
  }

  network {
    id = 0
    model  = "virtio"
    bridge = each.value.network_bridge
  }
}
