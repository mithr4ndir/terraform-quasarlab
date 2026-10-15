terraform {
  backend "local" {
    path = "/mnt/terraform-state/state/llm/terraform.tfstate"
  }
}
