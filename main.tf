# Configure the Azure provider
provider "azurerm" {
  # Replace these values with your own subscription ID and tenant ID
  subscription_id = "b9334351-cec8-405d-8358-51846fa2a3ab"
  tenant_id       = "b9a44c5c-ec32-467d-8c4b-534b3f2ea9db"

  features {}
}

# Declare variables for the function app and storage account names
variable "function_app_name" {
  description = "Name of the function app"
  default     = "my-function-app"
}

variable "storage_account_name" {
  description = "Name of the storage account"
  default     = "mystorageaccount"
}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  number  = true
  special = false
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.function_app_name}-rg"
  location = "westeurope"
}

# Create a storage account
resource "azurerm_storage_account" "storage" {
  name                      = "${var.storage_account_name}${random_string.suffix.result}"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true

  tags = {
    environment = "dev"
  }
}

# Create an app service plan
resource "azurerm_app_service_plan" "asp" {
  name                = "${var.function_app_name}-${random_string.suffix.result}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

# Create the function app
resource "azurerm_function_app" "function_app" {
  name                       = "${var.function_app_name}-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  app_service_plan_id        = azurerm_app_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "14.16.0"
  }

  version = "~2"

  site_config {
    always_on = true
  }

  tags = {
    environment = "dev"
  }
}
