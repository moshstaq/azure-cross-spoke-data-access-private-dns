variable "zone_name" {
  description = "Private DNS zone name e.g. privatelink.blob.core.windows.net"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to host the DNS zone"
  type        = string
}

# Map of link_name => vnet_id
# Example: { "hub" = "/subscriptions/.../vnet-hub", "spoke" = "/subscriptions/.../vnet-spoke" }
variable "vnet_links" {
  description = "Map of VNet link names to VNet resource IDs"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
