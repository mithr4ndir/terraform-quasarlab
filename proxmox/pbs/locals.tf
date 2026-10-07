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
      # No memory hotplug, deliberately, and this is an exception to the
      # fleet-wide decision in #29 that all resources stay hot-pluggable.
      # Two reasons, both measured:
      #   1. The debian-12 cloud kernel sets auto_online_blocks=offline, so
      #      hot-added DIMMs never come online. These guests booted showing
      #      908MB of their configured 4096MB, 24 of 32 blocks offline.
      #   2. Hotplug boots a guest with 1 GiB static RAM, and kernel.threads-max
      #      is computed once from that and never recomputed, permanently
      #      capping every percentage-derived limit. That is what killed
      #      herdr.service with EAGAIN at 1027 tasks on 2026-09-21.
      # pbs1 is the live A/B control for (2): threads-max 31240 here versus
      # 6847 on hotplug guests. It is a production backup server, so adding
      # hotplug back would regress it to 1 GiB static. The fleet repairs the
      # ceilings in Ansible instead (ansible-quasarlab#206, #210); that path
      # is fine for general guests and is not worth the risk here.
      hotplug        = "network,disk,usb,cpu"
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
      # No memory hotplug, deliberately, and this is an exception to the
      # fleet-wide decision in #29 that all resources stay hot-pluggable.
      # Two reasons, both measured:
      #   1. The debian-12 cloud kernel sets auto_online_blocks=offline, so
      #      hot-added DIMMs never come online. These guests booted showing
      #      908MB of their configured 4096MB, 24 of 32 blocks offline.
      #   2. Hotplug boots a guest with 1 GiB static RAM, and kernel.threads-max
      #      is computed once from that and never recomputed, permanently
      #      capping every percentage-derived limit. That is what killed
      #      herdr.service with EAGAIN at 1027 tasks on 2026-09-21.
      # pbs1 is the live A/B control for (2): threads-max 31240 here versus
      # 6847 on hotplug guests. It is a production backup server, so adding
      # hotplug back would regress it to 1 GiB static. The fleet repairs the
      # ceilings in Ansible instead (ansible-quasarlab#206, #210); that path
      # is fine for general guests and is not worth the risk here.
      hotplug        = "network,disk,usb,cpu"
      ipconfig0      = "ip=192.168.1.62/24,gw=192.168.1.1"
      target_node    = "pve2"
      tags           = "linux,backup,pbs"
    }
  }
}
