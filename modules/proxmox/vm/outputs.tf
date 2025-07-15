output "vm_id" {
  value = proxmox_vm_qemu.this.id
}

output "vm_ip" {
  value = proxmox_vm_qemu.this.default_ipv4_address
}
