terraform {
  backend "azurerm" {
    resource_group_name  = "rg-dbclick"
    storage_account_name = "tfstatedbclick"
    container_name       = "tfstate"
    key                 = "terraform.tfstate"
    use_azuread_auth    = true
    use_oidc            = true
    subscription_id     = "250d1287-152a-48e8-8b1c-2e7a9a8b3256"
    tenant_id           = "4b1d7455-1388-4836-b4b9-0095dd2f4c45"
  }
}
