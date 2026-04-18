variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the resource group to create"
  type        = string
  default     = "rg-data-access"

}

variable "virtual_network" {
  description = "Name of the azure virtual network"
  type        = string
}
variable "address_space" {
  description = "The address IP for the VNet"
  type        = list(string)
}


variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    environment = "dev"
    workload    = "data-access"
    managed_by  = "terraform"
  }
}
