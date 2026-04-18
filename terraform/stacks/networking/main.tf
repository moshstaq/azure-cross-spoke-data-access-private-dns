module "networking" {
  source = "../../modules/networking"

  location            = "eastus2"
  resource_group_name = "rg-data-access"
  vnet_name           = "vnet-data-access"
  address_space       = ["10.2.0.0/16"]
  subnet_name         = "snet-data-access"
  address_prefixes    = ["10.2.1.0/24"]

  # Sourced from hub's remote state 
  hub_vnet_id             = data.terraform_remote_state.connectivity.outputs.vnet_hub_id
  hub_vnet_name           = data.terraform_remote_state.connectivity.outputs.vnet_hub_name
  hub_resource_group_name = data.terraform_remote_state.connectivity.outputs.resource_group_name

  tags = {
    environment = "dev"
    workload    = "data-access"
    managed_by  = "terraform"
  }
}
