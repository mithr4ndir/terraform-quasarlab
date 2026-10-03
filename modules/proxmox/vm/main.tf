provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_parallel     = 5
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "this" {
  for_each = var.vms

  name            = each.key
  # Per-VM, falling back to the module-wide node. Declaring the wrong node here
  # is not a cosmetic diff: on an imported VM, Terraform sees target_node as
  # absent in state and adds the configured value, which for a VM that lives
  # somewhere else means an apply tries to MIGRATE it. wazuh and authentik are
  # on pve2 while their modules said pve, and jellyfin is the mirror of that.
  target_node     = coalesce(each.value.target_node, var.pm_node)
  agent           = 1
  clone           = each.value.template
  full_clone      = each.value.full_clone
  onboot          = each.value.onboot
  memory          = each.value.memory
  # `memory` stays IN the hotplug string: resizing a VM without a reboot is
  # wanted here. The cost is that PVE then boots the guest with 1 GiB of static
  # RAM and hot-adds the rest, and Linux sizes kernel.threads-max once, during
  # early boot, from what it saw then. A 16 GiB VM therefore starts life with
  # the thread ceilings of a 1 GiB one, which is what killed herdr.service on
  # command-center1 on 2026-09-21.
  #
  # That is repaired in code rather than by giving up hotplug, in three places
  # because the kernel derives three different things from that one number:
  #
  #   kernel.threads-max      ansible-quasarlab vm_baseline, sysctl, fleet-wide
  #   DefaultTasksMax, slice  ansible-quasarlab cmd_center, absolute drop-ins
  #   RLIMIT_NPROC            /etc/security/limits.d, because pam_limits resets
  #                           it after systemd applies the unit's LimitNPROC
  #
  # Verified across a real reboot on 2026-10-02, with memory hotplug enabled:
  # threads-max 130032, DefaultTasksMax 8192, user slice 8192. Only RLIMIT_NPROC
  # came back wrong (3423), which is what the limits.d entry addresses.
  #
  # If a guest ever needs the kernel to size its own ceilings correctly at boot,
  # drop `memory` from its hotplug string and cold boot it. That is a per-VM
  # decision, not the default.
  hotplug         = each.value.hotplug
  skip_ipv6       = each.value.skip_ipv6
  scsihw          = "virtio-scsi-single"
  ciuser          = each.value.username
  cipassword      = each.value.password
  ciupgrade       = true
  sshkeys         = var.sshkeys
  ipconfig0       = each.value.ipconfig0
  bootdisk        = "scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          storage    = each.value.storage_pool
          size       = each.value.storage_size
          asyncio    = "io_uring"
          cache      = "writeback"
          discard    = true
          iothread   = true
          # Must stay true: with backup=false the disk is excluded from vzdump,
          # so a backup job still runs green and writes an archive containing
          # no disks. Every VM had this set, which is why the cluster had no
          # usable backups (ansible-quasarlab#173).
          backup     = var.disk_backup
          emulatessd = true
        }
      }
    }
    ide {
      ide2 {
        ignore = true
      }
    }
  }

  cpu { 
    cores          = each.value.cores
    sockets        = each.value.sockets
    numa           = true
    type           = "host"
  }

  network {
    id = 0
    model  = "virtio"
    bridge = each.value.network_bridge
  }

  # Attributes a running VM cannot report, so an imported resource always
  # differs from config on them, and all three force REPLACEMENT.
  #
  # `clone` and `full_clone` describe how the VM was created. The Proxmox API
  # has no field for either, so import leaves them empty and false, and the
  # declared template name and full_clone = true then read as a change that can
  # only be satisfied by destroying and recreating the VM. On command-center1,
  # which runs the agent fleet and the Ansible control node, a plan said
  # "1 to add, 1 to destroy" immediately after a clean import.
  #
  # `ciuser` and `cipassword` are cloud-init values that only ever apply on
  # first boot (changing them needs a VM recreate anyway), and the API does not
  # return the password at all.
  #
  # `define_connection_info` is a provider-side toggle, not VM state.
  #
  # ignore_changes affects existing resources only, so a VM that Terraform
  # genuinely creates still gets the declared template and full clone.
  lifecycle {
    ignore_changes = [
      clone,
      full_clone,
      ciuser,
      cipassword,
      define_connection_info,
    ]
  }
}
