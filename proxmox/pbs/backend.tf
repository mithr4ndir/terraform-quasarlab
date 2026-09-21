terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/pbs/terraform.tfstate"
  }
}
