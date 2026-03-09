terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/fleetdm/terraform.tfstate"
  }
}
