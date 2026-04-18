# These outputs are what downstream stacks consume via remote_state
output "vnet_id" {
  value = module.networking.vnet_id
}

output "vnet_name" {
  value = module.networking.vnet_name
}

output "subnet_id" {
  value = module.networking.subnet_id
}

output "resource_group_name" {
  value = module.networking.resource_group_name
}
