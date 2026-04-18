# Read hub VNet ID from connectivity state
data "terraform_remote_state" "connectivity" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "platform-connectivity.tfstate"
  }
}

# Read data spoke VNet ID from networking stack state
# This is the fix for the duplicate data block bug — two blocks, two names
data "terraform_remote_state" "data_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "spoke-data-access-networking.tfstate"
  }
}
