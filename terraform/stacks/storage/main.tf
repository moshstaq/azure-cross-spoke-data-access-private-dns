module "storage" {
  source = "../../modules/storage"

  location            = "eastus2"
  resource_group_name = data.terraform_remote_state.networking.outputs.resource_group_name
  name_prefix         = "dataaccess"

  subnet_id           = data.terraform_remote_state.networking.outputs.subnet_id
  private_dns_zone_id = data.terraform_remote_state.connectivity.outputs.private_dns_zone_blob_id

  tags = {
    environment = "dev"
    workload    = "data-access"
    managed_by  = "terraform"
  }
}
