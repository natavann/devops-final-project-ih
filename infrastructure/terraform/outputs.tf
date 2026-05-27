output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.expensy.name
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.expensy.name
}

output "cluster_fqdn" {
  description = "Full DNS hostname of the cluster"
  value       = azurerm_kubernetes_cluster.expensy.fqdn
}

output "app_url" {
  description = "Application URL"
  value       = "http://nata-expensy.azure.ironlabs.online"
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.expensy.login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = azurerm_container_registry.expensy.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "ACR admin password"
  value       = azurerm_container_registry.expensy.admin_password
  sensitive   = true
}

output "dns_zone_name_servers" {
  description = "DNS zone name servers"
  value       = azurerm_dns_zone.expensy.name_servers
}

output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}
