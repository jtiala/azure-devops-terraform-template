variable "tenant_id" {
  type = string
  description = "Azure tenant ID"
}

variable "subscription_id" {
  type = string
  description = "Azure subscription ID"
}

variable "client_id" {
  type = string
  description = "Azure service principal ID"
}

variable "client_secret" {
  type = string
  description = "Azure service srincipal client secret"
}

variable "location" {
  type = string
  description = "Azure location"
}

variable "env" {
  type = string
  description = "Environment identifier"
}

variable "prefix" {
  type = string
  description = "Short prefix for all the resource names"
}

variable "cr_sku" {
  type = string
  description = "Azure Container Registry SKU"
}

variable "api_asp_sku_tier" {
  type = string
  description = "Azure App Service Plan tier for API app"
}

variable "api_asp_sku_size" {
  type = string
  description = "Azure App Service Plan size for API app"
}

variable "api_app_always_on" {
  type = string
  description = "always_on setting for API app"
}

variable "func_asp_sku_tier" {
  type = string
  description = "Azure App Service Plan tier for Functions app"
}

variable "func_asp_sku_size" {
  type = string
  description = "Azure App Service Plan size for Functions app"
}

variable "func_app_always_on" {
  type = string
  description = "always_on setting for Functions app"
}
