terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/wazuh/terraform.tfstate"
  }
}
