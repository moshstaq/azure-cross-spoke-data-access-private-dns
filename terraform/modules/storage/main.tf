
#--------------------------------------------------------------
# Random Suffix (Storage account names must be globally unique)
#--------------------------------------------------------------

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false # Storage accounts: lowercase only!
}

#--------------------------------------------------------------
# Storage Account
#--------------------------------------------------------------

resource "azurerm_storage_account" "this" {
  name                = "stspokeaccess${random_string.storage_suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Standard tier, Locally Redundant (cheapest option)
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true


  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false


  tags = var.tags
}

#--------------------------------------------------------------
# Private Endpoint for Storage Account (Blob)
#--------------------------------------------------------------

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${azurerm_storage_account.main.name}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = data.azurerm_subnet.data.id

  private_service_connection {
    name                           = "psc-${azurerm_storage_account.main.name}-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false

    subresource_names = ["blob"]
  }

  tags = var.tags
}

#--------------------------------------------------------------
# Private DNS Zone for Blob Storage
#--------------------------------------------------------------

resource "azurerm_private_dns_zone" "blob" {

  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

