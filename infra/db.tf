resource "azurerm_cosmosdb_account" "dba" {
  name = "${var.prefix}-${var.env}-dba"
  location = var.location
  resource_group_name = azurerm_resource_group.main-rg.name
  offer_type = "Standard"
  kind = "MongoDB"

  consistency_policy {
    consistency_level = "BoundedStaleness"
    max_interval_in_seconds = 10
    max_staleness_prefix = 200
  }

  geo_location {
    location = var.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableAggregationPipeline"
  }

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}

resource "azurerm_cosmosdb_mongo_database" "db" {
  name = var.prefix
  resource_group_name = azurerm_resource_group.main-rg.name
  account_name = azurerm_cosmosdb_account.dba.name
}
