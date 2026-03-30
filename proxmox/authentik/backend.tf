terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/authentik/terraform.tfstate"
  }
}
