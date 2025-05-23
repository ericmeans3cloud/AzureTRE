locals {
  core_vnet                 = "vnet-${var.tre_id}"
  core_resource_group_name  = "rg-${var.tre_id}"
  core_keyvault_name        = "kv-${var.tre_id}"
  cmk_name                  = "tre-encryption-${var.tre_id}"
  encryption_identity_name  = "id-encryption-${var.tre_id}"
  datafactory_identity_name = "id-adf-${var.tre_id}"

  datafactory_identity_id           = var.use_external_identity ? data.azurerm_user_assigned_identity.datafactory_external_identity[0].id : azurerm_user_assigned_identity.datafactory_identity[0].id
  datafactory_identity_principal_id = var.use_external_identity ? data.azurerm_user_assigned_identity.datafactory_external_identity[0].principal_id : azurerm_user_assigned_identity.datafactory_identity[0].principal_id

  tre_shared_service_tags = {
    tre_id                = var.tre_id
    tre_shared_service_id = var.tre_resource_id
  }

  role_definition_ids = {
    storage_blob_data_contributor           = "${data.azurerm_subscription.current.id}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    storage_file_data_smb_share_contributor = "${data.azurerm_subscription.current.id}/providers/Microsoft.Authorization/roleDefinitions/0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb"
    key_vault_administrator                 = "${data.azurerm_subscription.current.id}/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483"
    key_vault_secrets_user                  = "${data.azurerm_subscription.current.id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
  }
}