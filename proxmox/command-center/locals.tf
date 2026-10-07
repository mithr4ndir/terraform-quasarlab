locals {
  sshkeys = file("~/.ssh/id_rsa.pub")
  vms = {
    command-center1 = {
      template        = "ubuntu-24-04-cloud-init-template"
      username        = var.vm_defaults.username
      password        = var.vm_defaults.password
      memory          = 16384
      cores           = 8
      sockets         = 1
      storage_pool    = "nvme_1tb"
      storage_size    = "250G"
      network_bridge  = var.vm_defaults.network_bridge
      skip_ipv6       = true
      onboot          = true
      full_clone      = true
      hotplug         = "network,disk,usb,memory,cpu"
      ipconfig0       = "ip=192.168.1.88/24,gw=192.168.1.1"
      target_node     = "pve2"
    }
  }
}
