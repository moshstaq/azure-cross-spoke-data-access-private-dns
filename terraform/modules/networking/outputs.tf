# networking/outputs.tf
output "vnet_data_access_id" {
  value = azurerm_virtual_network.this.id
}

output "subnet_data_access_id" {
  value = azurerm_subnet.this.id
}
