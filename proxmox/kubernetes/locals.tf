# Locals for Proxmox Kubernetes setup, worker and control plane VMs in one vm to save on resources
locals {
  sshkeys = file("~/.ssh/id_rsa.pub")
  vms = {
    k8cluster1 = {
      template        = "ubuntu-24-04-cloud-init-template"
      username        = var.vm_defaults.username
      password        = var.vm_defaults.password
      memory          = 16384
      cores           = 8
      sockets         = 1
      storage_pool    = "truenas-iscsi"
      storage_size    = "150G"
      network_bridge  = var.vm_defaults.network_bridge
      skip_ipv6       = true
      onboot          = true
      full_clone      = true
      hotplug         = "network,disk,usb,memory,cpu"
      target_node     = "pve"
    }
    k8cluster2 = {
      template        = "ubuntu-24-04-cloud-init-template"
      username        = var.vm_defaults.username
      password        = var.vm_defaults.password
      memory          = 16384
      cores           = 8
      sockets         = 1
      storage_pool    = "truenas-iscsi"
      storage_size    = "150G"
      network_bridge  = var.vm_defaults.network_bridge
      skip_ipv6       = true
      onboot          = true
      full_clone      = true
      hotplug         = "network,disk,usb,memory,cpu"
      target_node     = "pve2"
    }
    k8cluster3 = {
      template        = "ubuntu-24-04-cloud-init-template"
      username        = var.vm_defaults.username
      password        = var.vm_defaults.password
      memory          = 16384
      cores           = 8
      sockets         = 1
      storage_pool    = "truenas-iscsi"
      storage_size    = "150G"
      network_bridge  = var.vm_defaults.network_bridge
      skip_ipv6       = true
      onboot          = true
      full_clone      = true
      hotplug         = "network,disk,usb,memory,cpu"
      target_node     = "pve2"
    }
  }
}
