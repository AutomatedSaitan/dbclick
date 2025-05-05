provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "dbclick-rg"
  location = "East US"
}

// VNet and Subnets
resource "azurerm_virtual_network" "vnet" {
  name                = "dbclick-vnet"
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
}

// MySQL Database
resource "azurerm_mysql_flexible_server" "db" {
  name                = "dbclick-mysql"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  administrator_login = var.db_user
  administrator_password = var.db_password
  sku_name            = "Standard_B1ms"
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

resource "azurerm_app_service" "app" {
  name                = "dbclick-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.app_plan.id
  app_settings = {
    DB_HOST     = azurerm_mysql_flexible_server.db.fqdn
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
    DB_NAME     = "dbclick"
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
