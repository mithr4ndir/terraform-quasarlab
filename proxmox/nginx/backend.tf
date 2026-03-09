terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/nginx/terraform.tfstate"
  }
}
