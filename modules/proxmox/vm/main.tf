provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "this" {
  for_each = var.vms

  name            = each.key
  target_node     = var.pm_node
  clone           = each.value.template
  full_clone      = each.value.full_clone
  onboot          = each.value.onboot
  cores           = each.value.cores
  sockets         = each.value.sockets
  memory          = each.value.memory
  hotplug         = each.value.hotplug
  sshkeys         = each.value.sshkeys
  ipconfig0       = each.value.ipconfig0
  ciuser          = each.value.username
  cipassword      = each.value.password
  ci_custom       = true
  bootdisk        = "scsi0"
  scsihw          = "virtio-scsi-pci"

  disk {
    slot     = 0
    type     = "scsi"
    storage  = each.value.storage_pool
    size     = "20G"
  }

  network {
    model  = "virtio"
    bridge = each.value.network_bridge
  }

  lifecycle {
    ignore_changes = [
      network,
      disk
    ]
  }
}
