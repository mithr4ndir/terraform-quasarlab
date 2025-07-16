locals {
  sshkeys = file("~/.ssh/id_rsa.pub")
  vms = {
    command-center2 = {
      template        = "ubuntu-24-04-cloud-init-template"
      username        = var.pm_user
      password        = var.pm_password
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
