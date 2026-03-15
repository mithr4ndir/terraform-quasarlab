locals {
  ci_section = one([
    for s in data.onepassword_item.pve.section : s if s.label == "Cloud-Init"
  ])

  sshkeys = one([
    for f in local.ci_section.field : f.value if f.label == "ssh_public_key"
  ])

  ci_username = one([
    for f in local.ci_section.field : f.value if f.label == "ci_username"
  ])

  ci_password = one([
    for f in local.ci_section.field : f.value if f.label == "ci_password"
  ])

  vms = {
    wazuh = {
      template       = "ubuntu-24-04-cloud-init-template"
      username       = local.ci_username
      password       = local.ci_password
      memory         = 16384
      cores          = 4
      sockets        = 1
      storage_pool   = var.vm_defaults.storage_pool
      storage_size   = var.vm_defaults.storage_size
      network_bridge = var.vm_defaults.network_bridge
      skip_ipv6      = true
      onboot         = true
      full_clone     = true
      hotplug        = "network,disk,usb,memory,cpu"
      ipconfig0      = "ip=192.168.1.171/24,gw=192.168.1.1"
    }
  }
}
