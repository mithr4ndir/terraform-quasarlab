terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/jellyfin/terraform.tfstate"
  }
}
