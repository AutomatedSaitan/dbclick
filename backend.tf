terraform {
  backend "azurerm" {
    resource_group_name  = "rg-dbclick"
    storage_account_name = "tfstatedbclick"
    container_name       = "tfstate"
    key                 = "terraform.tfstate"
    use_cli            = true
  }
}
