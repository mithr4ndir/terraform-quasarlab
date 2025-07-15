output "vm_ids" {
  value = { for k, m in module.vms : k => m.vm_id }
}

output "vm_ips" {
  value = { for k, m in module.vms : k => m.vm_ip }
}