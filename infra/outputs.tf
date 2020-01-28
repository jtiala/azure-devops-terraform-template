output "cr_login_server" {
  value = azurerm_container_registry.cr.login_server
}

output "api_app_default_site_hostname" {
  value = azurerm_app_service.api-app.default_site_hostname
}

output "func_app_default_hostname" {
  value = azurerm_function_app.func-app.default_hostname
}

output "db_connection_string" {
  value = azurerm_cosmosdb_account.dba.connection_strings[0]
  sensitive = true
}

output "db_name" {
  value = azurerm_cosmosdb_mongo_database.db.name
}
