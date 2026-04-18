variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for storage resources"
  type        = string
}

variable "name_prefix" {
  description = "Short prefix for storage account name (lowercase, no hyphens)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the Private Endpoint NIC will be placed"
  type        = string
}

variable "private_dns_zone_id" {
  description = "Resource ID of the Private DNS Zone for blob storage"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
