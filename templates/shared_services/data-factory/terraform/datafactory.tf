resource "azurerm_data_factory" "adf" {
  name                             = "adf-${var.tre_id}"
  resource_group_name              = data.azurerm_resource_group.rg.name
  location                         = data.azurerm_resource_group.rg.location
  managed_virtual_network_enabled  = true
  public_network_enabled           = false
  customer_managed_key_id          = var.enable_cmk_encryption ? data.azurerm_key_vault_key.tre_encryption_key[0].versionless_id : null
  customer_managed_key_identity_id = var.enable_cmk_encryption ? data.azurerm_user_assigned_identity.tre_encryption_identity[0].id : null
  tags                             = local.tre_shared_service_tags

  dynamic "identity" {
    for_each = var.user_assigned_identity_name != "" ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [local.datafactory_identity_id]
    }
  }

  lifecycle { ignore_changes = [tags, github_configuration, global_parameter] }
}

# The IR name is hardcoded because ADF best practice is to use the same IR name across environments in order to make
# pipelines work when promoted from one environment to another.
resource "azurerm_data_factory_integration_runtime_azure" "autoresolve_ir" {
  name                    = "adf-ir-tre"
  data_factory_id         = azurerm_data_factory.adf.id
  location                = "AutoResolve"
  virtual_network_enabled = true
}

# resource "azurerm_data_factory_linked_service_key_vault" "tre_kv" {
#   name            = "ls_keyvault"
#   data_factory_id = azurerm_data_factory.adf.id
#   key_vault_id    = data.azurerm_key_vault.keyvault.id
# }

# resource "azurerm_data_factory_linked_service_azure_blob_storage" "ls_blob" {
#   name              = "ls_intermediate_blob"
#   data_factory_id   = azurerm_data_factory.adf.id
#   connection_string = azurerm_storage_account.intermediate_storage.primary_connection_string
# }

# resource "azurerm_data_factory_linked_service_azure_file_storage" "ls_file" {
#   name              = "ls_intermediate_file"
#   data_factory_id   = azurerm_data_factory.adf.id
#   connection_string = azurerm_storage_account.intermediate_storage.primary_connection_string
# }

resource "azurerm_private_endpoint" "adfpe" {
  name                = "pe-adf-${var.tre_id}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  subnet_id           = data.azurerm_subnet.shared.id
  tags                = local.tre_shared_service_tags
  lifecycle { ignore_changes = [tags] }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-datafactory"
    private_dns_zone_ids = [azurerm_private_dns_zone.datafactory.id]
  }

  private_service_connection {
    name                           = "psc-adf-${var.tre_id}"
    private_connection_resource_id = azurerm_data_factory.adf.id
    is_manual_connection           = false
    subresource_names              = ["datafactory"]
  }
}

resource "azurerm_private_endpoint" "adfportalpe" {
  name                = "pe-adf-portal-${var.tre_id}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  subnet_id           = data.azurerm_subnet.shared.id
  tags                = local.tre_shared_service_tags
  lifecycle { ignore_changes = [tags] }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-datafactory-portal"
    private_dns_zone_ids = [azurerm_private_dns_zone.adf.id]
  }

  private_service_connection {
    name                           = "psc-adf-portal-${var.tre_id}"
    private_connection_resource_id = azurerm_data_factory.adf.id
    is_manual_connection           = false
    subresource_names              = ["portal"]
  }

  # private endpoints in serial
  depends_on = [
    azurerm_private_endpoint.adfpe
  ]
}

# TODO: Automatically approve these MPEs
# See https://stackoverflow.com/questions/68898346/how-to-use-terraform-to-approve-a-managed-private-endpoint-on-a-blob-storage-adl
# and https://github.com/hashicorp/terraform-provider-azurerm/issues/19777
resource "azurerm_data_factory_managed_private_endpoint" "intermediate_blob_storage" {
  name               = "mpe-intermediate-blob-storage"
  data_factory_id    = azurerm_data_factory.adf.id
  target_resource_id = azurerm_storage_account.intermediate_storage.id
  subresource_name   = "blob"
}

resource "azurerm_data_factory_managed_private_endpoint" "intermediate_file_storage" {
  name               = "mpe-intermediate-file-storage"
  data_factory_id    = azurerm_data_factory.adf.id
  target_resource_id = azurerm_storage_account.intermediate_storage.id
  subresource_name   = "file"
}

resource "azurerm_data_factory_managed_private_endpoint" "intermediate_dfs_storage" {
  name               = "mpe-intermediate-dfs-storage"
  data_factory_id    = azurerm_data_factory.adf.id
  target_resource_id = azurerm_storage_account.intermediate_storage.id
  subresource_name   = "dfs"
}

resource "azurerm_data_factory_managed_private_endpoint" "adf_kv" {
  name               = "mpe-key-vault"
  data_factory_id    = azurerm_data_factory.adf.id
  target_resource_id = azurerm_key_vault.kv.id
  subresource_name   = "Vault"
}