resource_group_name = "rg-voting-app-prod"
location           = "East US"
cluster_name       = "aks-voting-app-prod"
kubernetes_version = "1.27.7"
environment        = "prod"
owner              = "Production Team"

# Node configuration for production
node_count        = 3
min_node_count    = 2
max_node_count    = 10
node_vm_size      = "Standard_D4s_v3"

# Features
enable_application_gateway = true
enable_monitoring         = true
enable_backup            = true
log_retention_days       = 90

# Additional tags
tags = {
  CostCenter = "Production"
  Purpose    = "Live-Environment"
  Criticality = "High"
}