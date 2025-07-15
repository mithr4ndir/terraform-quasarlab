locals {
  vms = {
    command-center = {
      template        = "ubuntu-24-04-cloud-init-template"
      ipconfig0       = "ip=dhcp"
      sshkeys         = var.vm_defaults.sshkeys
      username        = var.vm_defaults.username
      password        = var.vm_defaults.password
      memory          = 8192
      cores           = 4
      sockets         = 1
      storage_pool    = var.vm_defaults.storage_pool
      network_bridge  = var.vm_defaults.network_bridge
      skip_ipv6       = true
      onboot          = true
      full_clone      = true
      hotplug         = "network,disk,usb,memory,cpu"
    }
  }
}
