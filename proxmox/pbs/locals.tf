locals {
  sshkeys = file("~/.ssh/id_rsa.pub")

  # Proxmox Backup Server, one instance per cluster node.
  #
  # pbs1 is the primary: both PVE hosts back up to it. pbs2 holds a replica,
  # pulled with a PBS sync job, so a complete set of every VM exists on both
  # physical hosts. Backing up once and replicating costs half the read load
  # on the guests compared with each host backing up to two targets.
  #
  # PBS runs on plain Debian via the proxmox-backup-server package, so the
  # whole thing stays Terraform + Ansible managed with no ISO install.
  #
  # The datastore is a SECOND disk (scsi1) on each node's near-empty thin
  # pool. Keeping it off the OS disk means a runaway datastore cannot wedge
  # the guest, and the datastore can be grown or detached independently.
  vms = {
    pbs1 = {
      template       = "debian-12-cloud-init-template"
      username       = var.vm_defaults.username
      password       = var.vm_defaults.password
      memory         = 4096
      cores          = 2
      sockets        = 1
      storage_pool   = "SSD1"
      storage_size   = "32G"
      data_disk_pool = "SSD2"
      data_disk_size = "600G"
      network_bridge = var.vm_defaults.network_bridge
      skip_ipv6      = true
      onboot         = true
      full_clone     = true
      hotplug        = "network,disk,usb,memory,cpu"
      ipconfig0      = "ip=192.168.1.61/24,gw=192.168.1.1"
      target_node    = "pve"
      tags           = "linux,backup,pbs"
    }
    pbs2 = {
      template       = "debian-12-cloud-init-template"
      username       = var.vm_defaults.username
      password       = var.vm_defaults.password
      memory         = 4096
      cores          = 2
      sockets        = 1
      storage_pool   = "ssd_1"
      storage_size   = "32G"
      data_disk_pool = "ssd_2"
      data_disk_size = "600G"
      network_bridge = var.vm_defaults.network_bridge
      skip_ipv6      = true
      onboot         = true
      full_clone     = true
      hotplug        = "network,disk,usb,memory,cpu"
      ipconfig0      = "ip=192.168.1.62/24,gw=192.168.1.1"
      target_node    = "pve2"
      tags           = "linux,backup,pbs"
    }
  }
}
