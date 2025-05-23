output "data_factory_name" {
  value = azurerm_data_factory.adf.name
}

output "connection_uri" {
  value = "https://adf.azure.com/en/home?factory=${azurerm_data_factory.adf.id}"
}

output "intermediate_storage_account_name" {
  value = azurerm_storage_account.intermediate_storage.name
}

output "intermediate_blob_storage_domain" {
  value = azurerm_storage_account.intermediate_storage.primary_blob_host
}

output "intermediate_file_storage_domain" {
  value = azurerm_storage_account.intermediate_storage.primary_file_host
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}