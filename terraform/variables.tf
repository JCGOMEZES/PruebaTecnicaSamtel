variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-voting-app-prod"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
  
  validation {
    condition = contains([
      "East US", "East US 2", "West US", "West US 2", "West US 3",
      "Central US", "North Central US", "South Central US", "West Central US",
      "Canada Central", "Canada East",
      "Brazil South",
      "North Europe", "West Europe", "UK South", "UK West",
      "France Central", "Germany West Central", "Norway East", "Switzerland North",
      "UAE North", "South Africa North",
      "Australia East", "Australia Southeast",
      "East Asia", "Southeast Asia", "Japan East", "Japan West",
      "Korea Central", "India Central"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-voting-app"
  
  validation {
    condition     = can(regex("^[a-z0-9-]{1,63}$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric characters or hyphens, 1-63 characters long."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.27.7"
}

variable "node_count" {
  description = "Initial number of nodes in the default node pool"
  type        = number
  default     = 2
  
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "Node count must be between 1 and 10."
  }
}

variable "min_node_count" {
  description = "Minimum number of nodes for auto-scaling"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_node_count >= 1 && var.min_node_count <= 100
    error_message = "Min node count must be between 1 and 100."
  }
}

variable "max_node_count" {
  description = "Maximum number of nodes for auto-scaling"
  type        = number
  default     = 5
  
  validation {
    condition     = var.max_node_count >= 1 && var.max_node_count <= 100
    error_message = "Max node count must be between 1 and 100."
  }
}

variable "node_vm_size" {
  description = "VM size for the default node pool"
  type        = string
  default     = "Standard_D2s_v3"
  
  validation {
    condition = contains([
      "Standard_A2_v2", "Standard_A4_v2", "Standard_A8_v2",
      "Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3",
      "Standard_D2s_v4", "Standard_D4s_v4", "Standard_D8s_v4",
      "Standard_B2s", "Standard_B4ms", "Standard_B8ms"
    ], var.node_vm_size)
    error_message = "VM size must be a valid Azure VM size for AKS."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps Team"
}

variable "enable_application_gateway" {
  description = "Enable Application Gateway for ingress"
  type        = bool
  default     = false
}

variable "postgres_password" {
  description = "Password for PostgreSQL database"
  type        = string
  sensitive   = true
  default     = "VotingApp2024!"
  
  validation {
    condition     = length(var.postgres_password) >= 8
    error_message = "PostgreSQL password must be at least 8 characters long."
  }
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor and Log Analytics"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable backup for persistent volumes"
  type        = bool
  default     = true
}

variable "network_policy" {
  description = "Network policy for AKS (azure, calico, none)"
  type        = string
  default     = "azure"
  
  validation {
    condition     = contains(["azure", "calico", "none"], var.network_policy)
    error_message = "Network policy must be azure, calico, or none."
  }
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = ""
}

variable "enable_rbac" {
  description = "Enable Kubernetes RBAC"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
  
  validation {
    condition     = var.log_retention_days >= 7 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 7 and 730."
  }
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}