module "vms" {
  source            = "../../modules/proxmox/vm"
  proxmox_user      = var.pm_user
  proxmox_password  = var.pm_password
  proxmox_api_url   = var.pm_api_url
  pm_node           = var.pm_node
  vms               = local.vms
  sshkeys           = var.sshkeys
}
