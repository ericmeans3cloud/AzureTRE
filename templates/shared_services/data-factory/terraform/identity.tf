resource "azurerm_user_assigned_identity" "datafactory_identity" {
  count               = var.use_external_identity ? 0 : 1
  name                = local.datafactory_identity_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
}