terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "250d1287-152a-48e8-8b1c-2e7a9a8b3256"
}

data "azurerm_subscription" "current" {}

data "azurerm_user_assigned_identity" "app_identity" {
  name                = "Deployment"
  resource_group_name = "az-rg-dbclick"
}

// Add User Access Administrator role to managed identity
resource "azurerm_role_assignment" "user_access_admin" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = data.azurerm_user_assigned_identity.app_identity.principal_id
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-dbclick"
  location = "Sweden Central"
}

// VNet and Subnets
resource "azurerm_virtual_network" "vnet" {
  name                = "az-vnet-dbclick"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  timeouts {
    create = "2h"
  }

  depends_on = [azurerm_resource_group.rg, azurerm_role_assignment.user_access_admin]
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  delegation {
    name = "app-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  depends_on = [azurerm_subnet.db_subnet]

  timeouts {
    create = "2h"
  }
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "db-delegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  depends_on = [azurerm_virtual_network.vnet]

  timeouts {
    create = "2h"
  }
}

// Add Private DNS Zone
resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "mysql-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_private_dns_zone.mysql
  ]

  timeouts {
    create = "2h"
  }
}

// MySQL Database
resource "azurerm_mysql_flexible_server" "db" {
  name                   = "dbclick-mysql"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  zone                   = "1"
  administrator_login    = var.db_user
  administrator_password = var.db_password
  sku_name               = "B_Standard_B1ms"
  delegated_subnet_id    = azurerm_subnet.db_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.mysql.id

  depends_on = [
    azurerm_subnet.db_subnet,
    azurerm_private_dns_zone_virtual_network_link.mysql
  ]

  timeouts {
    create = "2h"
  }
}

resource "azurerm_mysql_flexible_database" "database" {
  name                = "dbclick"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

resource "azurerm_mysql_flexible_server_configuration" "allow_app_access" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db.name
  value               = "OFF"
}

resource "azurerm_mysql_flexible_server_firewall_rule" "allow_app_subnet" {
  name                = "allow-app-subnet"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db.name
  start_ip_address    = cidrhost(azurerm_subnet.app_subnet.address_prefixes[0], 0)
  end_ip_address      = cidrhost(azurerm_subnet.app_subnet.address_prefixes[0], 255)
}

// App Service
resource "azurerm_service_plan" "app_plan" {
  name                = "dbclick-app-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"

  depends_on = [azurerm_resource_group.rg]

  timeouts {
    create = "2h"
  }
}

resource "azurerm_linux_web_app" "app" {
  name                     = "dbclick-app"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  service_plan_id          = azurerm_service_plan.app_plan.id
  virtual_network_subnet_id = azurerm_subnet.app_subnet.id

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.app_identity.id]
  }

  app_settings = {
    DB_HOST                = azurerm_mysql_flexible_server.db.fqdn
    DB_USER                = var.db_user
    DB_PASSWORD            = var.db_password
    DB_NAME                = "dbclick"
    WEBSITE_DNS_SERVER     = "168.63.129.16"
  }

  site_config {
    always_on = false
    vnet_route_all_enabled = true
    container_registry_managed_identity_client_id = data.azurerm_user_assigned_identity.app_identity.client_id
    container_registry_use_managed_identity       = true
    application_stack {
      docker_image_name   = "dbclick-app:latest"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
  }

  depends_on = [
    azurerm_service_plan.app_plan, 
    azurerm_mysql_flexible_server.db,
    azurerm_private_dns_zone_virtual_network_link.mysql
  ]

  timeouts {
    create = "2h"
  }
}

// Add Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

// Assign ACR Push role to managed identity
resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_user_assigned_identity.app_identity.principal_id
}

// Add AcrPull role assignment for web app
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_user_assigned_identity.app_identity.principal_id
}

// Add ACR Webhook
resource "azurerm_container_registry_webhook" "acr_webhook" {
  name                = "webappupdate01"
  resource_group_name = azurerm_resource_group.rg.name
  registry_name       = azurerm_container_registry.acr.name
  location            = azurerm_resource_group.rg.location

  service_uri = "https://${azurerm_linux_web_app.app.site_credential[0].name}:${azurerm_linux_web_app.app.site_credential[0].password}@${azurerm_linux_web_app.app.name}.scm.azurewebsites.net/docker/hook"
  
  actions = ["push"]
  status  = "enabled"
  scope   = "dbclick-app:latest"
  
  custom_headers = {
    "Content-Type" = "application/json"
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
  description = "Service principal client ID for ACR"
}

variable "client_secret" {
  description = "Service principal client secret for ACR"
  sensitive   = true
}

variable "container_registry_name" {
  description = "Name of the Azure Container Registry"
}
