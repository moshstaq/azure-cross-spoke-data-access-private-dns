
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "rg-platform-connectivity"
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_to_hub" {
  name                  = "link-blob-hub"
  resource_group_name   = "rg-platform-connectivity"
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_to_app_dev" {
  name                  = "link-blob-app-dev"
  resource_group_name   = "rg-platform-connectivity"
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.app_dev.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_to_data" {
  name                  = "link-blob-data"
  resource_group_name   = "rg-platform-connectivity"
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.data.id
  registration_enabled  = false
}
