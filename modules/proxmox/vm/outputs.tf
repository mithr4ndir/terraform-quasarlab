output "vm_ids" {
  value = { for k, vm in proxmox_vm_qemu.this : k => vm.id }
}

output "vm_ips" {
  value = { for k, vm in proxmox_vm_qemu.this : k => vm.default_ipv4_address }
}
