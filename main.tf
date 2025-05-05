provider "azurerm" {
  features {}
  subscription_id = "250d1287-152a-48e8-8b1c-2e7a9a8b3256"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-dbclick"
  location = "Canada Central"
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
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
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

// Private DNS Zone
resource "azurerm_private_dns_zone" "mysql_dns" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_link" {
  name                  = "mysql-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

// Private Endpoint
resource "azurerm_private_endpoint" "mysql_pe" {
  name                = "mysql-private-endpoint"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.app_subnet.id

  private_service_connection {
    name                           = "mysql-private-connection"
    private_connection_resource_id = azurerm_mysql_flexible_server.db.id
    subresource_names             = ["mysqlServer"]
    is_manual_connection          = false
  }

  private_dns_zone_group {
    name                 = "mysql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.mysql_dns.id]
  }
}

// App Service
resource "azurerm_service_plan" "app_plan" {
  name                = "dbclick-app-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "app" {
  name                = "dbclick-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.app_plan.id
  
  app_settings = {
    DB_HOST     = azurerm_private_endpoint.mysql_pe.private_service_connection[0].private_ip_address
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
    DB_NAME     = "dbclick"
  }

  site_config {
    always_on = false
    application_stack {
      docker_image_name = "azacrdbclick-cmeqbmhgamadhreg.azurecr.io/dbclick-app:latest"
      docker_registry_url = "https://azacrdbclick-cmeqbmhgamadhreg.azurecr.io"
      docker_registry_username = var.client_id
      docker_registry_password = var.client_secret
    }
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

variable "client_id" {
  description = "Container registry username"
}

variable "client_secret" {
  description = "Container registry password"
  sensitive   = true
}
