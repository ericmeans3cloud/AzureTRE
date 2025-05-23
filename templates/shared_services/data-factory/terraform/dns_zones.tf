resource "azurerm_private_dns_zone" "datafactory" {
  name                = "privatelink.datafactory.azure.net"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.tre_shared_service_tags

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "datafactory" {
  resource_group_name   = data.azurerm_resource_group.rg.name
  virtual_network_id    = data.azurerm_virtual_network.core.id
  private_dns_zone_name = azurerm_private_dns_zone.datafactory.name
  name                  = "azure-datafactory-link"
  registration_enabled  = false
  tags                  = local.tre_shared_service_tags
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone" "adf" {
  name                = "privatelink.adf.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.tre_shared_service_tags

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "adf" {
  resource_group_name   = data.azurerm_resource_group.rg.name
  virtual_network_id    = data.azurerm_virtual_network.core.id
  private_dns_zone_name = azurerm_private_dns_zone.adf.name
  name                  = "azure-adf-link"
  registration_enabled  = false
  tags                  = local.tre_shared_service_tags
  lifecycle { ignore_changes = [tags] }
}