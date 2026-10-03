locals {
  sshkeys = file("~/.ssh/id_rsa.pub")
  vms = {
    nginx1 = {
      template        = "ubuntu-24-04-cloud-init-template"
      username        = var.vm_defaults.username
      password        = var.vm_defaults.password
      memory          = 4096
      cores           = 2
      sockets         = 1
      storage_pool    = "truenas-iscsi"
      storage_size    = "54784M"
      network_bridge  = var.vm_defaults.network_bridge
      skip_ipv6       = true
      onboot          = true
      full_clone      = true
      hotplug         = "network,disk,usb,memory,cpu"
      target_node     = "pve"
    }
    nginx2 = {
      template        = "ubuntu-24-04-cloud-init-template"
      username        = var.vm_defaults.username
      password        = var.vm_defaults.password
      memory          = 4096
      cores           = 2
      sockets         = 1
      storage_pool    = "truenas-iscsi"
      storage_size    = "54784M"
      network_bridge  = var.vm_defaults.network_bridge
      skip_ipv6       = true
      onboot          = true
      full_clone      = true
      hotplug         = "network,disk,usb,memory,cpu"
      target_node     = "pve"
    }
  }
}
