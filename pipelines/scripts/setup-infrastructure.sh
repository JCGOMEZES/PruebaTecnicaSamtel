#!/bin/bash
set -euo pipefail

# Infrastructure setup script for Azure resources
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-voting-app-prod}"
LOCATION="${LOCATION:-East US}"
CLUSTER_NAME="${CLUSTER_NAME:-aks-voting-app}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"

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

# Function to check Azure CLI login
check_azure_login() {
    log "Checking Azure CLI login status..."
    
    if ! az account show >/dev/null 2>&1; then
        error "Not logged into Azure CLI"
        log "Please run: az login"
        exit 1
    fi
    
    local current_subscription=$(az account show --query id -o tsv)
    if [ "$current_subscription" != "$SUBSCRIPTION_ID" ]; then
        log "Setting subscription to: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
    
    success "Azure CLI configured correctly"
}

# Function to create resource group
create_resource_group() {
    log "Creating resource group: $RESOURCE_GROUP"
    
    if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
        warning "Resource group $RESOURCE_GROUP already exists"
    else
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        success "Resource group created: $RESOURCE_GROUP"
    fi
}

# Function to run Terraform
run_terraform() {
    log "Running Terraform to create infrastructure..."
    
    local terraform_dir="../terraform"
    cd "$terraform_dir"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log "Planning Terraform deployment..."
    terraform plan \
        -var="resource_group_name=$RESOURCE_GROUP" \
        -var="location=$LOCATION" \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="environment=production" \
        -out=tfplan
    
    # Apply deployment
    log "Applying Terraform deployment..."
    terraform apply -auto-approve tfplan
    
    success "Terraform deployment completed"
    
    # Get outputs
    log "Getting Terraform outputs..."
    terraform output -json > terraform-outputs.json
    
    # Extract important values
    local cluster_name=$(terraform output -raw aks_cluster_name)
    local resource_group=$(terraform output -raw resource_group_name)
    
    # Get AKS credentials
    log "Getting AKS credentials..."
    az aks get-credentials --resource-group "$resource_group" --name "$cluster_name" --overwrite-existing
    
    success "Infrastructure setup completed successfully"
}

# Function to install ingress controller
install_ingress_controller() {
    log "Installing NGINX Ingress Controller..."
    
    # Add ingress-nginx helm repository
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install ingress controller
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
        --wait
    
    success "NGINX Ingress Controller installed"
    
    # Wait for external IP
    log "Waiting for external IP assignment..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    
    local external_ip=""
    local attempts=0
    while [ -z "$external_ip" ] && [ $attempts -lt 30 ]; do
        external_ip=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ -z "$external_ip" ]; then
            log "Waiting for external IP... (attempt $((attempts + 1))/30)"
            sleep 10
            ((attempts++))
        fi
    done
    
    if [ -n "$external_ip" ]; then
        success "External IP assigned: $external_ip"
        echo "EXTERNAL_IP=$external_ip" >> $GITHUB_ENV || true
    else
        warning "External IP not assigned yet. Check status later with: kubectl get svc -n ingress-nginx"
    fi
}

# Function to setup monitoring
setup_monitoring() {
    log "Setting up monitoring with Prometheus and Grafana..."
    
    # Add helm repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Prometheus
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set grafana.adminPassword=admin123 \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.retention=7d \
        --wait
    
    success "Monitoring stack installed"
    
    # Get Grafana admin password
    local grafana_password=$(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
    log "Grafana admin password: $grafana_password"
}

# Main function
main() {
    log "Starting infrastructure setup..."
    log "Resource Group: $RESOURCE_GROUP"
    log "Location: $LOCATION"
    log "Cluster Name: $CLUSTER_NAME"
    
    check_azure_login
    create_resource_group
    run_terraform
    install_ingress_controller
    setup_monitoring
    
    success "Infrastructure setup completed successfully!"
    
    log "Next steps:"
    log "1. Run deployment script to deploy the application"
    log "2. Access applications via the external IP"
    log "3. Monitor with Grafana dashboard"
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi