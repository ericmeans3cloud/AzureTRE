# This is a separate Key Vault for storing secrets to be used in ADF pipelines, such as connection information for
# on-prem resources; it is separate from the TRE Core KV for security and isolation reasons.
locals {
  kv_name                          = "kv-${azurerm_data_factory.adf.name}"
  kv_public_network_access_enabled = true
  kv_network_default_action        = "Deny"
  kv_network_bypass                = "AzureServices"
}

resource "azurerm_key_vault" "kv" {
  name                      = local.kv_name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  resource_group_name       = data.azurerm_resource_group.rg.name
  location                  = data.azurerm_resource_group.rg.location
  sku_name                  = "standard"
  enable_rbac_authorization = true
  purge_protection_enabled  = true
  tags                      = local.tre_shared_service_tags

  public_network_access_enabled = local.kv_public_network_access_enabled

  network_acls {
    default_action = local.kv_network_default_action
    bypass         = local.kv_network_bypass
  }

  # Allow changes to the network access model so that honest brokers can add IP exceptions
  lifecycle {
    ignore_changes = [public_network_access_enabled, network_acls, tags]
  }
}

resource "azurerm_role_assignment" "keyvault_deployer_role" {
  scope              = azurerm_key_vault.kv.id
  role_definition_id = local.role_definition_ids.key_vault_administrator
  principal_id       = data.azurerm_client_config.current.object_id // deployer - either CICD service principal or local user
}

resource "azurerm_role_assignment" "keyvault_adfidentity_role" {
  count              = var.user_assigned_identity_name != "" ? 1 : 0
  scope              = azurerm_key_vault.kv.id
  role_definition_id = local.role_definition_ids.key_vault_secrets_user
  principal_id       = local.datafactory_identity_principal_id
}

resource "azurerm_private_endpoint" "adfkvpe" {
  name                = "pe-kv-${azurerm_data_factory.adf.name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  subnet_id           = data.azurerm_subnet.shared.id
  tags                = local.tre_shared_service_tags

  lifecycle { ignore_changes = [tags] }

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.vaultcore.id]
  }

  private_service_connection {
    name                           = "psc-kv-${azurerm_data_factory.adf.name}"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diagnostics-kv-${azurerm_data_factory.adf.name}"
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.core.id

  dynamic "enabled_log" {
    for_each = ["AuditEvent", "AzurePolicyEvaluationDetails"]
    content {
      category = enabled_log.value
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }

  lifecycle { ignore_changes = [log_analytics_destination_type] }
}
