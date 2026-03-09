terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/command-center/terraform.tfstate"
  }
}
