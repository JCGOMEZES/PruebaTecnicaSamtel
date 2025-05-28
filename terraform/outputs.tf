output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_node_resource_group" {
  description = "Auto-generated resource group for AKS nodes"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "kube_config" {
  description = "Kubernetes configuration"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "container_registry_login_server" {
  description = "Login server for the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "container_registry_admin_username" {
  description = "Admin username for the container registry"
  value       = azurerm_container_registry.main.admin_username
}

output "container_registry_admin_password" {
  description = "Admin password for the container registry"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

output "public_ip_address" {
  description = "Public IP address for the application gateway"
  value       = azurerm_public_ip.app_gateway.ip_address
}

output "public_ip_fqdn" {
  description = "FQDN for the public IP"
  value       = azurerm_public_ip.app_gateway.fqdn
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "application_gateway_public_ip" {
  description = "Public IP of the Application Gateway"
  value       = var.enable_application_gateway ? azurerm_application_gateway.main[0].frontend_ip_configuration[0].public_ip_address_id : null
}

output "cluster_endpoint" {
  description = "Endpoint URL for accessing the voting application"
  value       = "http://${azurerm_public_ip.app_gateway.fqdn}"
}

output "voting_app_url" {
  description = "URL for the voting application"
  value       = "http://${azurerm_public_ip.app_gateway.fqdn}/vote"
}

output "results_app_url" {
  description = "URL for the results application"
  value       = "http://${azurerm_public_ip.app_gateway.fqdn}/result"
}
