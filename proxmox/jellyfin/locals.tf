locals {
  sshkeys = file("~/.ssh/id_rsa.pub")
  vms = {
    jellyfin = {
      template        = "ubuntu-24-04-cloud-init-template"
      username        = var.vm_defaults.username
      password        = var.vm_defaults.password
      memory          = 12288
      cores           = 6
      sockets         = 1
      storage_pool    = var.vm_defaults.storage_pool
      storage_size    = var.vm_defaults.storage_size
      network_bridge  = var.vm_defaults.network_bridge
      skip_ipv6       = true
      onboot          = true
      full_clone      = true
      hotplug         = "network,disk,usb,memory,cpu"
      ipconfig0       = "ip=192.168.1.170/24,gw=192.168.1.1"
    }
  }
}
