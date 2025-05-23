data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azurerm_virtual_network" "core" {
  name                = local.core_vnet
  resource_group_name = local.core_resource_group_name
}

data "azurerm_subnet" "shared" {
  resource_group_name  = local.core_resource_group_name
  virtual_network_name = local.core_vnet
  name                 = "SharedSubnet"
}

data "azurerm_key_vault" "keyvault" {
  name                = local.core_keyvault_name
  resource_group_name = local.core_resource_group_name
}

data "azurerm_resource_group" "rg" {
  name = local.core_resource_group_name
}

data "azurerm_key_vault_key" "tre_encryption_key" {
  count        = var.enable_cmk_encryption ? 1 : 0
  name         = local.cmk_name
  key_vault_id = var.key_store_id
}

data "azurerm_user_assigned_identity" "tre_encryption_identity" {
  count               = var.enable_cmk_encryption ? 1 : 0
  name                = local.encryption_identity_name
  resource_group_name = local.core_resource_group_name
}

data "azurerm_user_assigned_identity" "datafactory_external_identity" {
  count               = var.use_external_identity ? 1 : 0
  name                = var.user_assigned_identity_name
  resource_group_name = var.user_assigned_identity_rg
}

data "azurerm_private_dns_zone" "blobcore" {
  name                = module.terraform_azurerm_environment_configuration.private_links["privatelink.blob.core.windows.net"]
  resource_group_name = local.core_resource_group_name
}

data "azurerm_private_dns_zone" "filecore" {
  name                = module.terraform_azurerm_environment_configuration.private_links["privatelink.file.core.windows.net"]
  resource_group_name = local.core_resource_group_name
}

data "azurerm_private_dns_zone" "vaultcore" {
  name                = module.terraform_azurerm_environment_configuration.private_links["privatelink.vaultcore.azure.net"]
  resource_group_name = local.core_resource_group_name
}

data "azurerm_log_analytics_workspace" "core" {
  name                = "log-${var.tre_id}"
  resource_group_name = local.core_resource_group_name
}