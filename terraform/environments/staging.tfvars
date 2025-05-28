resource_group_name = "rg-voting-app-staging"
location           = "East US"
cluster_name       = "aks-voting-app-staging"
kubernetes_version = "1.27.7"
environment        = "staging"
owner              = "QA Team"

# Node configuration for staging
node_count        = 2
min_node_count    = 1
max_node_count    = 4
node_vm_size      = "Standard_D2s_v3"

# Features
enable_application_gateway = true
enable_monitoring         = true
enable_backup            = true
log_retention_days       = 30

# Additional tags
tags = {
  CostCenter = "QualityAssurance"
  Purpose    = "Pre-production"
}
