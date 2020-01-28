terraform {
  required_version = ">= 0.11"

  backend "azurerm" {}
}

provider "azurerm" {
  version = "~> 1.40"

  client_id = var.client_id
  client_secret = var.client_secret
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id

  # Do not register unused resource providers.
  # Useful for environments with restricted permissions.
  skip_provider_registration = true
}

resource "azurerm_resource_group" "main-rg" {
  name = "${var.prefix}-${var.env}-main-rg"
  location = var.location

  tags = {
    env = "${var.prefix}-${var.env}"
  }
}
