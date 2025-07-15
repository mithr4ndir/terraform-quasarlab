provider "azuread" {
  tenant_id = var.tenant_id
}

resource "azuread_user" "ladino" {
  user_principal_name     = "demo.user@yourtenant.onmicrosoft.com"
  display_name            = "Demo User"
  password                = "StrongPassw0rd!"
  force_password_change   = false
}

resource "azuread_group" "pim_group" {
  display_name     = "PrivilegedAccessTeam"
  security_enabled = true
}

resource "azuread_group_member" "add_demo_user" {
  group_object_id  = azuread_group.pim_group.id
  member_object_id = azuread_user.demo_user.id
}