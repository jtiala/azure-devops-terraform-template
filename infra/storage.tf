resource "azurerm_storage_account" "sa" {
  name = "${var.prefix}${var.env}sa"
  resource_group_name = azurerm_resource_group.main-rg.name
  location = var.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  enable_blob_encryption = true
  enable_file_encryption = true
  enable_https_traffic_only = true

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}

resource "azurerm_storage_container" "logs-sc" {
  name = "logs"
  storage_account_name = azurerm_storage_account.sa.name
  container_access_type = "private"
}

data "azurerm_storage_account_sas" "logs-sc-sas-token" {
  connection_string = azurerm_storage_account.sa.primary_connection_string
  https_only = true

  resource_types {
    service = false
    container = true
    object = false
  }

  services {
    blob = true
    queue = false
    table = false
    file = false
  }

  # Hard coded because dynamic values would trigger Terraform apply every time the pipeline is ran
  start = "2020-01-01"
  expiry = "2040-01-01"

  permissions {
    read = true
    write = true
    delete = true
    list = false
    add = false
    create = false
    update = false
    process = false
  }
}

locals {
  logs_sas_url = "${azurerm_storage_account.sa.primary_blob_endpoint}${azurerm_storage_container.logs-sc.name}?${data.azurerm_storage_account_sas.logs-sc-sas-token.sas}"
}
