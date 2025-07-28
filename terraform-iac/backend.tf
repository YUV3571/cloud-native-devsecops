terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  # Example for using Azure Storage as a remote backend
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "tfstate<random_suffix>"
  #   container_name       = "tfstate"
  #   key                  = "cloud-native-devsecops.tfstate"
  # }
}
