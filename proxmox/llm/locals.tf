locals {
  sshkeys = var.ssh_public_key

  # Local LLM host: llama.cpp server on pve2's RTX 2080 Ti (TU102, 11 GB).
  #
  # The card has been bound to vfio-pci and assigned to nothing since jellyfin
  # dropped it on 2026-05-31, after it kept falling off the bus under NVENC and
  # HDR tone mapping. Inference is a different load, but that is a hypothesis,
  # so this VM starts life as a burn-in and nothing depends on it yet.
  #
  # Passthrough rather than an LXC on the host driver, deliberately: pve2 also
  # runs two of the three etcd members and command-center1. With VFIO a driver
  # hang stays in the guest; with the host driver loaded it is a hypervisor
  # kernel problem. VFIO does not contain physical faults: a PCIe error or a
  # failed reset can still reach the host, which is why this is a burn-in.
  vms = {
    llm1 = {
      template = "ubuntu-24-04-cloud-init-template"
      # Two templates share that name (9000 and 9002). 9002 is the one built on
      # 2026-09-21 with a real serial0, so pin it by id.
      template_id = 9002
      username    = var.ci_username
      password    = var.ci_password
      memory      = 16384
      cores       = 8
      sockets     = 1
      # Local thin pool on pve2, not truenas-iscsi: model loads are large
      # sequential reads, and this VM should not care whether the NAS is up.
      storage_pool = "ssd_1"
      storage_size = "64G"
      # Model weights. Re-downloadable, so kept out of vzdump; the OS disk
      # stays in.
      data_disk_pool   = "ssd_1"
      data_disk_size   = "250G"
      data_disk_backup = false
      network_bridge   = var.vm_defaults.network_bridge
      skip_ipv6        = true
      # Off until the burn-in passes, so a pve2 reboot does not bring an
      # unproven GPU back up alongside the etcd members.
      onboot     = false
      full_clone = true
      # No memory hotplug. VFIO pins all guest RAM at start, so hotplug buys
      # nothing here, and it would boot the guest at 1 GiB static and cap
      # kernel.threads-max (see the module comment).
      hotplug = "network,disk,usb,cpu"
      machine = "q35"
      # 0a:00 without a function passes all four: VGA, audio, USB, UCSI.
      # They share an IOMMU group and cannot be split.
      pci_devices = [
        { raw_id = "0000:0a:00" },
      ]
      # Without an emulated display the GPU's option ROM becomes the primary
      # display under SeaBIOS, and this VM never left the firmware. See the
      # module comment on vga_type.
      vga_type      = "std"
      serial_socket = true
      target_node   = "pve2"
      # Confirmed outside the pfSense DHCP pool by the owner on 2026-10-15.
      ipconfig0 = "ip=192.168.1.180/24,gw=192.168.1.1"
      tags      = "linux,llm,gpu"
    }
  }
}
