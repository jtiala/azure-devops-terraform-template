resource "azurerm_container_registry" "cr" {
  name = "${var.prefix}${var.env}cr"
  resource_group_name = azurerm_resource_group.main-rg.name
  location = var.location
  sku = var.cr_sku
  admin_enabled = true

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}

resource "azurerm_app_service_plan" "api-asp" {
  name = "${var.prefix}-${var.env}-api-asp"
  location = var.location
  resource_group_name = azurerm_resource_group.main-rg.name
  kind = "Linux"
  reserved = true

  sku {
    tier = var.api_asp_sku_tier
    size = var.api_asp_sku_size
  }

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}

resource "azurerm_app_service" "api-app" {
  name = "${var.prefix}-${var.env}-api-app"
  location = var.location
  resource_group_name = azurerm_resource_group.main-rg.name
  app_service_plan_id = azurerm_app_service_plan.api-asp.id
  https_only = true

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
    DOCKER_REGISTRY_SERVER_URL = azurerm_container_registry.cr.login_server
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.cr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.cr.admin_password
    DB_CONNECTION_STRING = azurerm_cosmosdb_account.dba.connection_strings[0]
    DB_NAME = azurerm_cosmosdb_mongo_database.db.name
  }

  site_config {
    linux_fx_version = "DOCKER|${azurerm_container_registry.cr.login_server}/${var.prefix}-api:latest"
    always_on = var.api_app_always_on
    http2_enabled = true
    ftps_state = "Disabled"
  }

  logs {
    application_logs {
      azure_blob_storage {
        level = "Verbose"
        sas_url = local.logs_sas_url
        retention_in_days = 30
      }
    }

    http_logs {
      azure_blob_storage {
        sas_url = local.logs_sas_url
        retention_in_days = 30
      }
    }
  }

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}
