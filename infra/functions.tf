resource "azurerm_resource_group" "func-rg" {
  name = "${var.prefix}-${var.env}-func-rg"
  location = var.location

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}

resource "azurerm_app_service_plan" "func-asp" {
  name = "${var.prefix}-${var.env}-func-asp"
  location = var.location
  resource_group_name = azurerm_resource_group.func-rg.name
  kind = "FunctionApp"
  reserved = true

  sku {
    tier = var.func_asp_sku_tier
    size = var.func_asp_sku_size
  }

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}

resource "azurerm_application_insights" "func-insights" {
  name = "${var.prefix}-${var.env}-func-insights"
  location = var.location
  resource_group_name = azurerm_resource_group.func-rg.name
  application_type = "web"

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}

resource "azurerm_function_app" "func-app" {
  name = "${var.prefix}-${var.env}-func-app"
  location = var.location
  resource_group_name = azurerm_resource_group.func-rg.name
  app_service_plan_id = azurerm_app_service_plan.func-asp.id
  storage_connection_string = azurerm_storage_account.sa.primary_connection_string
  https_only = true
  version = "~3"

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    FUNCTIONS_EXTENSION_VERSION = "~3"
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.func-insights.instrumentation_key
    DB_CONNECTION_STRING = azurerm_cosmosdb_account.dba.connection_strings[0]
    DB_NAME = azurerm_cosmosdb_mongo_database.db.name
  }

  site_config {
    always_on = var.func_app_always_on
    linux_fx_version = "python|3.7"
  }

  tags = {
    env = "${var.prefix}-${var.env}"
  }

  lifecycle {
    ignore_changes = [
      app_settings
    ]
  }
}
