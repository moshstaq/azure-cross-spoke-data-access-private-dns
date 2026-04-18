resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-data-access"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space

  tags = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = "snet-data-access"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.address_prefixes
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-data-access"
  resource_group_name          = local.hub_resource_group_name
  virtual_network_name         = local.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.this.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-data-access-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.this.name
  remote_virtual_network_id    = local.hub_vnet_id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}
