terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/kubernetes/terraform.tfstate"
  }
}
