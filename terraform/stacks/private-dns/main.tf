module "private_dns_blob" {
  source = "../../modules/private-dns"

  zone_name           = "privatelink.blob.core.windows.net"
  resource_group_name = "rg-platform-connectivity"

  # Adding a new spoke = adding one line here
  vnet_links = {
    hub        = data.terraform_remote_state.connectivity.outputs.vnet_hub_id
    data-spoke = data.terraform_remote_state.data_spoke.outputs.vnet_id
  }

  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
