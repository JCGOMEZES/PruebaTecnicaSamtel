set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/deployment_${TIMESTAMP}.log"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-aks-voting-app}"
NAMESPACE="${NAMESPACE:-voting-app}"
ENVIRONMENT="${ENVIRONMENT:-production}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-voting-app}"

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}" | tee -a "$LOG_FILE"
}

print_info() {
    print_status "$BLUE" "INFO: $1"
}

print_success() {
    print_status "$GREEN" "SUCCESS: $1"
}

print_warning() {
    print_status "$YELLOW" "WARNING: $1"
}

print_error() {
    print_status "$RED" "ERROR: $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v az >/dev/null 2>&1 || missing_tools+=("azure-cli")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check Kubernetes connection
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Please ensure kubectl is configured correctly"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    print_info "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_info "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        print_success "Namespace $NAMESPACE created"
    fi
    
    # Label namespace
    kubectl label namespace "$NAMESPACE" environment="$ENVIRONMENT" --overwrite
}

# Function to deploy using Helm
deploy_with_helm() {
    print_info "Deploying application using Helm..."
    
    local helm_chart_path="${PROJECT_ROOT}/kubernetes/helm/voting-app"
    local values_file="${helm_chart_path}/values-${ENVIRONMENT}.yaml"
    
    # Check if environment-specific values file exists
    if [ ! -f "$values_file" ]; then
        print_warning "Environment-specific values file not found: $values_file"
        values_file="${helm_chart_path}/values.yaml"
    fi
    
    # Helm upgrade/install
    helm upgrade --install "$HELM_RELEASE_NAME" "$helm_chart_path" \
        --namespace "$NAMESPACE" \
        --values "$values_file" \
        --set global.imageTag="$IMAGE_TAG" \
        --set global.environment="$ENVIRONMENT" \
        --wait \
        --timeout=600s
    
    print_success "Helm deployment completed"
}

# Function to deploy using kubectl (fallback)
deploy_with_kubectl() {
    print_info "Deploying application using kubectl..."
    
    local manifests_dir="${PROJECT_ROOT}/kubernetes/environment"
    
    # Apply manifests in order
    local manifest_files=(
        "namespace.yaml"
        "configmap.yaml"
        "secrets.yaml"
        "redis-deployment.yaml"
        "postgres-deployment.yaml"
        "vote-deployment.yaml"
        "result-deployment.yaml"
        "worker-deployment.yaml"
    )
    
    for manifest in "${manifest_files[@]}"; do
        local manifest_path="${manifests_dir}/${manifest}"
        if [ -f "$manifest_path" ]; then
            print_info "Applying $manifest"
            envsubst < "$manifest_path" | kubectl apply -f -
        else
            print_warning "Manifest not found: $manifest_path"
        fi
    done
    
    # Apply ingress
    local ingress_path="${PROJECT_ROOT}/kubernetes/ingress/ingress.yaml"
    if [ -f "$ingress_path" ]; then
        print_info "Applying ingress configuration"
        envsubst < "$ingress_path" | kubectl apply -f -
    fi
    
    print_success "kubectl deployment completed"
}

# Function to wait for deployment
wait_for_deployment() {
    print_info "Waiting for deployments to be ready..."
    
    local deployments=("vote" "result" "worker" "postgres" "redis")
    
    for deployment in "${deployments[@]}"; do
        print_info "Waiting for deployment: $deployment"
        kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout=300s
    done
    
    print_success "All deployments are ready"
}

# Function to run smoke tests
run_smoke_tests() {
    print_info "Running smoke tests..."
    
    # Get service endpoints
    local vote_service=$(kubectl get service vote -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}:{.spec.ports[0].port}')
    local result_service=$(kubectl get service result -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}:{.spec.ports[0].port}')
    
    # Test vote service
    if kubectl exec -n "$NAMESPACE" deployment/vote -- wget -q --spider "http://$vote_service" 2>/dev/null; then
        print_success "Vote service is responding"
    else
        print_error "Vote service is not responding"
        return 1
    fi
    
    # Test result service
    if kubectl exec -n "$NAMESPACE" deployment/result -- wget -q --spider "http://$result_service" 2>/dev/null; then
        print_success "Result service is responding"
    else
        print_error "Result service is not responding"
        return 1
    fi
    
    print_success "Smoke tests passed"
}

# Function to get application URLs
get_application_urls() {
    print_info "Getting application URLs..."
    
    # Check if ingress exists
    if kubectl get ingress -n "$NAMESPACE" >/dev/null 2>&1; then
        local ingress_ip=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        local ingress_host=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
        
        if [ -n "$ingress_ip" ]; then
            print_success "Vote App: http://$ingress_ip/vote"
            print_success "Result App: http://$ingress_ip/result"
        elif [ -n "$ingress_host" ]; then
            print_success "Vote App: http://$ingress_host"
            print_success "Result App: http://$ingress_host"
        else
            print_warning "Ingress IP not yet assigned. Check status with: kubectl get ingress -n $NAMESPACE"
        fi
    else
        # Fallback to NodePort or port-forward
        print_info "No ingress found. Use port-forward to access services:"
        print_info "kubectl port-forward -n $NAMESPACE service/vote 8080:80"
        print_info "kubectl port-forward -n $NAMESPACE service/result 8081:80"
    fi
}

# Function to display deployment status
show_deployment_status() {
    print_info "Deployment Status Summary"
    echo "=========================="
    
    print_info "Pods:"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    print_info "Services:"
    kubectl get services -n "$NAMESPACE"
    
    print_info "Ingress:"
    kubectl get ingress -n "$NAMESPACE" 2>/dev/null || print_warning "No ingress found"
    
    print_info "Persistent Volumes:"
    kubectl get pv,pvc -n "$NAMESPACE" 2>/dev/null || print_warning "No persistent volumes found"
}

# Function to cleanup on failure
cleanup_on_failure() {
    print_error "Deployment failed. Cleaning up..."
    
    # Optionally rollback Helm release
    if command -v helm >/dev/null 2>&1; then
        helm rollback "$HELM_RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || true
    fi
    
    print_info "Cleanup completed. Check logs at: $LOG_FILE"
}

# Main deployment function
main() {
    print_info "Starting deployment of Voting App"
    print_info "Environment: $ENVIRONMENT"
    print_info "Namespace: $NAMESPACE"
    print_info "Image Tag: $IMAGE_TAG"
    print_info "Log File: $LOG_FILE"
    
    # Trap to handle failures
    trap cleanup_on_failure ERR
    
    # Execute deployment steps
    check_prerequisites
    create_namespace
    
    # Choose deployment method
    if command -v helm >/dev/null 2>&1 && [ -d "${PROJECT_ROOT}/kubernetes/helm/voting-app" ]; then
        deploy_with_helm
    else
        print_warning "Helm not available or chart not found. Using kubectl deployment"
        deploy_with_kubectl
    fi
    
    wait_for_deployment
    run_smoke_tests
    get_application_urls
    show_deployment_status
    
    print_success "Deployment completed successfully!"
    print_info "Log file saved at: $LOG_FILE"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi