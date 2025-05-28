resource_group_name = "rg-voting-app-dev"
location           = "East US"
cluster_name       = "aks-voting-app-dev"
kubernetes_version = "1.27.7"
environment        = "dev"
owner              = "Development Team"

# Node configuration for development
node_count        = 1
min_node_count    = 1
max_node_count    = 3
node_vm_size      = "Standard_B2s"

# Features
enable_application_gateway = false
enable_monitoring         = true
enable_backup            = false
log_retention_days       = 7

# Additional tags
tags = {
  CostCenter = "Development"
  Purpose    = "Testing"
}
