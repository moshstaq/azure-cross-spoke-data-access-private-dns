resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "this" {
  name                = "st${var.name_prefix}${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false

  tags = var.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${azurerm_storage_account.this.name}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id # passed in — module doesn't own networking

  private_service_connection {
    name                           = "psc-${azurerm_storage_account.this.name}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  # Wire up to the DNS zone — ID passed in from private-dns stack output
  private_dns_zone_group {
    name                 = "pdnszg-blob"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}
