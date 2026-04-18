data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {

    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "platform-connectivity.tfstate"
  }
}


data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {

    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "spoke-data-access-networking.tfstate"
  }
}




resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "rg-platform-connectivity"
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_to_hub" {
  name                  = "link-blob-hub"
  resource_group_name   = "rg-platform-connectivity"
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = data.terraform_remote_state.networking.outputs.vnet_hub_id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_to_spoke" {
  name                  = "link-blob-spoke"
  resource_group_name   = "rg-platform-connectivity"
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = data.terraform_remote_state.networking.outputs.vnet_spoke_id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_to_data" {
  name                  = "link-blob-data"
  resource_group_name   = "rg-platform-connectivity"
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = data.terraform_remote_state.networking.outputs.vnet_data_id
  registration_enabled  = false
}
