#!/bin/bash
set -euo pipefail

# Validation script for deployment
NAMESPACE="${NAMESPACE:-voting-app}"
TIMEOUT="${TIMEOUT:-300}"

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
    return 1
}

# Function to validate pod status
validate_pods() {
    log "Validating pod status..."
    
    local required_pods=("vote" "result" "worker" "postgres" "redis")
    local failed_pods=()
    
    for pod in "${required_pods[@]}"; do
        if kubectl get pods -n "$NAMESPACE" -l app="$pod" --no-headers | grep -q "Running"; then
            success "Pod $pod is running"
        else
            error "Pod $pod is not running"
            failed_pods+=("$pod")
        fi
    done
    
    if [ ${#failed_pods[@]} -ne 0 ]; then
        error "Failed pods: ${failed_pods[*]}"
        return 1
    fi
    
    success "All pods are running successfully"
}

# Function to validate services
validate_services() {
    log "Validating services..."
    
    local required_services=("vote" "result" "postgres" "redis")
    local failed_services=()
    
    for service in "${required_services[@]}"; do
        if kubectl get service "$service" -n "$NAMESPACE" >/dev/null 2>&1; then
            local endpoints=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}')
            if [ -n "$endpoints" ]; then
                success "Service $service has endpoints: $endpoints"
            else
                warning "Service $service has no endpoints"
                failed_services+=("$service")
            fi
        else
            error "Service $service not found"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -ne 0 ]; then
        error "Failed services: ${failed_services[*]}"
        return 1
    fi
    
    success "All services are healthy"
}

# Function to validate ingress
validate_ingress() {
    log "Validating ingress..."
    
    if kubectl get ingress -n "$NAMESPACE" >/dev/null 2>&1; then
        local ingress_ip=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ -n "$ingress_ip" ]; then
            success "Ingress has external IP: $ingress_ip"
        else
            warning "Ingress external IP not yet assigned"
        fi
    else
        warning "No ingress found in namespace $NAMESPACE"
    fi
}

# Function to run application tests
run_application_tests() {
    log "Running application functionality tests..."
    
    # Test vote service internal connectivity
    if kubectl exec -n "$NAMESPACE" deployment/vote -- wget -q --spider http://localhost:80 2>/dev/null; then
        success "Vote service internal connectivity test passed"
    else
        error "Vote service internal connectivity test failed"
        return 1
    fi
    
    # Test result service internal connectivity
    if kubectl exec -n "$NAMESPACE" deployment/result -- wget -q --spider http://localhost:80 2>/dev/null; then
        success "Result service internal connectivity test passed"
    else
        error "Result service internal connectivity test failed"
        return 1
    fi
    
    # Test database connectivity
    if kubectl exec -n "$NAMESPACE" deployment/postgres -- pg_isready -U postgres 2>/dev/null; then
        success "PostgreSQL connectivity test passed"
    else
        error "PostgreSQL connectivity test failed"
        return 1
    fi
    
    # Test Redis connectivity
    if kubectl exec -n "$NAMESPACE" deployment/redis -- redis-cli ping | grep -q "PONG"; then
        success "Redis connectivity test passed"
    else
        error "Redis connectivity test failed"
        return 1
    fi
    
    success "All application tests passed"
}

# Function to generate validation report
generate_report() {
    log "Generating validation report..."
    
    local report_file="/tmp/validation_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "VOTING APP DEPLOYMENT VALIDATION REPORT"
        echo "========================================"
        echo "Date: $(date)"
        echo "Namespace: $NAMESPACE"
        echo ""
        
        echo "PODS STATUS:"
        kubectl get pods -n "$NAMESPACE" -o wide
        echo ""
        
        echo "SERVICES STATUS:"
        kubectl get services -n "$NAMESPACE"
        echo ""
        
        echo "INGRESS STATUS:"
        kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "No ingress found"
        echo ""
        
        echo "PERSISTENT VOLUMES:"
        kubectl get pvc -n "$NAMESPACE" 2>/dev/null || echo "No PVCs found"
        echo ""
        
        echo "EVENTS (Last 10):"
        kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
        
    } > "$report_file"
    
    success "Validation report generated: $report_file"
    cat "$report_file"
}

# Main validation function
main() {
    log "Starting deployment validation..."
    log "Namespace: $NAMESPACE"
    log "Timeout: $TIMEOUT seconds"
    
    local validation_start=$(date +%s)
    local validation_passed=true
    
    # Run validation steps
    validate_pods || validation_passed=false
    validate_services || validation_passed=false
    validate_ingress
    run_application_tests || validation_passed=false
    
    local validation_end=$(date +%s)
    local duration=$((validation_end - validation_start))
    
    generate_report
    
    if [ "$validation_passed" = true ]; then
        success "All validations passed! (Duration: ${duration}s)"
        exit 0
    else
        error "Some validations failed! (Duration: ${duration}s)"
        exit 1
    fi
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi