terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm"}
    azapi   = { source = "azure/azapi"}
    random  = { source = "hashicorp/random"}
  }
}

provider "azurerm" {
  features {}
}
