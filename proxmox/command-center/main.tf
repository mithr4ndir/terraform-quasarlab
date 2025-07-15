module "vms" {
  source            = "./modules/proxmox/vm"
  pm_user           = var.pm_user
  pm_password       = var.pm_password
  proxmox_api_url   = var.pm_api_url
  pm_node           = var.pm_node
  vms               = local.vms
}
