terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-devops-demo"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-devops-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "devops-demo"

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_B2s"

    pod_subnet_id       = null # Set if using Azure CNI
    max_pods            = 50   # CKV_AZURE_168
    only_critical_addons_enabled = false # Allow normal workloads

  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure" # CKV2_AZURE_29, CKV_AZURE_7
    network_policy     = "azure" # CKV_AZURE_7
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
  }

  role_based_access_control_enabled = true
  azure_policy_enabled              = true # CKV_AZURE_116



  api_server_access_profile {
    authorized_ip_ranges = ["115.128.53.44"] # Only allow your current public IP
  }

  disk_encryption_set_id = azurerm_disk_encryption_set.example.id # CKV_AZURE_117

  private_cluster_enabled = false # CKV_AZURE_115 (now public for CLI access)

  sku_tier = "Standard" # CKV_AZURE_170


  linux_profile {
    admin_username = "azureuser"
    ssh_key {
      key_data = file("${path.module}/id_rsa_aks.pub")
    }
  }

 # CKV_AZURE_141


}

# Add required resources for references above
resource "azurerm_log_analytics_workspace" "law" {
  name                = "aks-law-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_disk_encryption_set" "example" {
  name                = "example-des"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  identity {
    type = "SystemAssigned"
  }

  key_vault_key_id = "https://proj1kv-new.vault.azure.net/keys/aks-encryption-key/73b184c68f814e039a192dc1844fcba5"
}



output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
