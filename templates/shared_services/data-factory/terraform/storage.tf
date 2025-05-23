resource "azurerm_storage_account" "intermediate_storage" {
  name                             = lower(replace("adf-stg-${var.tre_id}", "-", ""))
  resource_group_name              = data.azurerm_resource_group.rg.name
  location                         = data.azurerm_resource_group.rg.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  is_hns_enabled                   = true
  table_encryption_key_type        = var.enable_cmk_encryption ? "Account" : "Service"
  queue_encryption_key_type        = var.enable_cmk_encryption ? "Account" : "Service"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  local_user_enabled               = false
  public_network_access_enabled    = false
  tags                             = local.tre_shared_service_tags

  # changing this value is destructive, hence attribute is in lifecycle.ignore_changes block below
  infrastructure_encryption_enabled = true

  network_rules {
    default_action = "Deny"
  }

  dynamic "identity" {
    for_each = var.enable_cmk_encryption ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [data.azurerm_user_assigned_identity.tre_encryption_identity[0].id]
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.enable_cmk_encryption ? [1] : []
    content {
      key_vault_key_id          = data.azurerm_key_vault_key.tre_encryption_key[0].versionless_id
      user_assigned_identity_id = data.azurerm_user_assigned_identity.tre_encryption_identity[0].id
    }
  }

  lifecycle { ignore_changes = [infrastructure_encryption_enabled, tags] }
}

# The AzureRM provider does not support the ability to disable soft delete on containers/blobs/file shares so we have to use azapi
# We do not want soft delete enabled on this storage account as it is temp storage and we don't want anyone accessing deleted
# sensitive data.
resource "azapi_update_resource" "disable_blob_soft_delete" {
  type      = "Microsoft.Storage/storageAccounts/blobServices@2024-01-01"
  parent_id = azurerm_storage_account.intermediate_storage.id
  name      = "default"

  body = {
    properties = {
      containerDeleteRetentionPolicy = {
        enabled = false
      }
      deleteRetentionPolicy = {
        enabled = false
      }
    }
  }
}

resource "azapi_update_resource" "disable_file_soft_delete" {
  type        = "Microsoft.Storage/storageAccounts/fileServices@2024-01-01"
  resource_id = "${azurerm_storage_account.intermediate_storage.id}/fileServices/default"

  body = {
    properties = {
      shareDeleteRetentionPolicy = {
        enabled = false
      }
    }
  }
}

resource "azurerm_private_endpoint" "adfstgblobpe" {
  name                = "pe-blob-adf-${var.tre_id}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  subnet_id           = data.azurerm_subnet.shared.id
  tags                = local.tre_shared_service_tags
  lifecycle { ignore_changes = [tags] }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-blobcore"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blobcore.id]
  }

  private_service_connection {
    name                           = "psc-stg-adf-${var.tre_id}"
    private_connection_resource_id = azurerm_storage_account.intermediate_storage.id
    is_manual_connection           = false
    subresource_names              = ["Blob"]
  }

  # private endpoints in serial
  depends_on = [
    azurerm_private_endpoint.adfportalpe
  ]
}

resource "azurerm_private_endpoint" "adfstgfilepe" {
  name                = "pe-file-adf-${var.tre_id}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  subnet_id           = data.azurerm_subnet.shared.id
  tags                = local.tre_shared_service_tags

  lifecycle { ignore_changes = [tags] }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-filecore"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.filecore.id]
  }

  private_service_connection {
    name                           = "psc-filestg-adf-${var.tre_id}"
    private_connection_resource_id = azurerm_storage_account.intermediate_storage.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  # private endpoints in serial
  depends_on = [
    azurerm_private_endpoint.adfstgblobpe
  ]
}
