terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/postgresql/terraform.tfstate"
  }
}
