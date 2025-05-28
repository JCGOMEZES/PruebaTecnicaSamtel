#!/bin/bash
set -euo pipefail

# Cleanup script for removing resources
NAMESPACE="${NAMESPACE:-voting-app}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-voting-app-prod}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-voting-app}"
FORCE_DELETE="${FORCE_DELETE:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Function to confirm deletion
confirm_deletion() {
    if [ "$FORCE_DELETE" != "true" ]; then
        echo -e "${YELLOW}This will delete the following resources:${NC}"
        echo "- Helm release: $HELM_RELEASE_NAME"
        echo "- Namespace: $NAMESPACE"
        echo "- Azure Resource Group: $RESOURCE_GROUP (if specified)"
        echo ""
        read -p "Are you sure you want to continue? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            log "Cleanup cancelled by user"
            exit 0
        fi
    fi
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes() {
    log "Cleaning up Kubernetes resources..."
    
    # Remove Helm release
    if helm list -n "$NAMESPACE" | grep -q "$HELM_RELEASE_NAME"; then
        log "Uninstalling Helm release: $HELM_RELEASE_NAME"
        helm uninstall "$HELM_RELEASE_NAME" -n "$NAMESPACE"
        success "Helm release removed"
    else
        warning "Helm release $HELM_RELEASE_NAME not found"
    fi
    
    # Remove namespace and all resources
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log "Deleting namespace: $NAMESPACE"
        kubectl delete namespace "$NAMESPACE" --timeout=300s
        success "Namespace deleted"
    else
        warning "Namespace $NAMESPACE not found"
    fi
    
    # Cleanup persistent volumes
    log "Cleaning up persistent volumes..."
    kubectl get pv | grep "$NAMESPACE" | awk '{print $1}' | xargs -r kubectl delete pv || true
}

# Function to cleanup Azure resources
cleanup_azure() {
    if [ -n "${CLEANUP_AZURE:-}" ] && [ "$CLEANUP_AZURE" = "true" ]; then
        log "Cleaning up Azure resources..."
        
        if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
            log "Deleting resource group: $RESOURCE_GROUP"
            az group delete --name "$RESOURCE_GROUP" --yes --no-wait
            success "Azure resource group deletion initiated"
        else
            warning "Resource group $RESOURCE_GROUP not found"
        fi
    fi
}

# Function to cleanup local files
cleanup_local() {
    log "Cleaning up local temporary files..."
    
    # Remove temporary files
    rm -f /tmp/deployment_*.log
    rm -f terraform.tfstate.backup
    rm -f tfplan
    rm -rf temp-files/
    
    success "Local cleanup completed"
}

# Main cleanup function
main() {
    log "Starting cleanup process..."
    
    confirm_deletion
    cleanup_kubernetes
    cleanup_azure
    cleanup_local
    
    success "Cleanup completed successfully!"
    
    if [ "${CLEANUP_AZURE:-}" = "true" ]; then
        warning "Azure resources are being deleted in the background"
        log "Check status with: az group show --name $RESOURCE_GROUP"
    fi
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi