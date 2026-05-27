# Resource Group
resource "azurerm_resource_group" "expensy" {
  name     = var.resource_group_name
  location = var.location
}

# Azure Container Registry
resource "azurerm_container_registry" "expensy" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.expensy.name
  location            = azurerm_resource_group.expensy.location
  sku                 = "Basic"
  admin_enabled       = true
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "expensy" {
  name                = var.cluster_name
  location            = azurerm_resource_group.expensy.location
  resource_group_name = azurerm_resource_group.expensy.name
  dns_prefix          = var.dns_prefix

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.node_vm_size
    zones      = var.availability_zones
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  tags = {
    Environment = "production"
    Project     = "expensy"
  }
}

# Allow AKS to pull images from ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.expensy.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.expensy.id
  skip_service_principal_aad_check = true
}
