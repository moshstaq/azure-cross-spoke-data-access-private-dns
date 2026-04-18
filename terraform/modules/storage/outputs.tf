output "storage_account_id" {
  description = "Resource ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.this.name
}

output "private_endpoint_id" {
  description = "Resource ID of the blob private endpoint"
  value       = azurerm_private_endpoint.blob.id
}
