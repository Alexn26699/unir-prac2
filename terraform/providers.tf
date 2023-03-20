provider "azurerm" {
  features {}
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.78.0"
    }
  }
  
  backend "azurerm" {
    resource_group_name   = "RG-TERRAFORM-STATES"
    storage_account_name  = "unirterraformstates"
    container_name        = "tfcluster"
    key                   = "org.terraform.tfaksprecluster"
  }
}