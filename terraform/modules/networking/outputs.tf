output "vnet_id" {
  description = "Resource ID of the created VNet"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the created VNet"
  value       = azurerm_virtual_network.this.name
}

output "subnet_id" {
  description = "Resource ID of the created subnet"
  value       = azurerm_subnet.this.id
}

output "resource_group_name" {
  description = "Resource group containing networking resources"
  value       = azurerm_resource_group.this.name
}
