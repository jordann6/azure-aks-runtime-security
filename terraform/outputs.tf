output "resource_group_name" {
  description = "Resource group holding the lab"
  value       = azurerm_resource_group.this.name
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.this.name
}

output "get_credentials_command" {
  description = "Command to fetch kubeconfig for the cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name}"
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace backing Defender for Containers"
  value       = azurerm_log_analytics_workspace.this.id
}

output "defender_for_containers_enabled" {
  description = "Whether the Defender for Containers subscription plan is managed by this stack"
  value       = var.enable_defender_for_containers
}
