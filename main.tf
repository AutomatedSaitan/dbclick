provider "azurerm" {
  features {}
  subscription_id = "250d1287-152a-48e8-8b1c-2e7a9a8b3256"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-dbclick"
  location = "Poland Central"
}

// VNet and Subnets
resource "azurerm_virtual_network" "vnet" {
  name                = "az-vnet-dbclick"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
      name = "delegation"
  
      service_delegation {
        name    = "Microsoft.DBforMySQL/flexibleServers"
        #actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
      }
    }
}

// MySQL Database
resource "azurerm_mysql_flexible_server" "db" {
  name                = "dbclick-mysql"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  administrator_login = var.db_user
  administrator_password = var.db_password
  sku_name            = "B_Standard_B1ms"
  delegated_subnet_id = azurerm_subnet.db_subnet.id
}

// App Service
resource "azurerm_app_service_plan" "app_plan" {
  name                = "dbclick-app-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_linux_web_app" "app" {
  name                = "dbclick-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_app_service_plan.app_plan.id
  
  app_settings = {
    DB_HOST     = azurerm_mysql_flexible_server.db.fqdn
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
    DB_NAME     = "dbclick"
  }

  site_config {
    linux_fx_version = "DOCKER|azacrdbclick-cmeqbmhgamadhreg.azurecr.io/dbclick-app:latest"
  }
}

// Define variables for sensitive data
variable "db_user" {
  description = "Database username"
}

variable "db_password" {
  description = "Database password"
  sensitive   = true
}
