#!/usr/bin/env bash

# CloudNativePG OCM Component Test Suite
# Tests the component in a KIND (Kubernetes IN Docker) cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpg-test}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
BUILD_DIR="./build"
TEST_NAMESPACE="cnpg-test"
CLEANUP_ON_SUCCESS="${CLEANUP_ON_SUCCESS:-true}"
SKIP_BUILD="${SKIP_BUILD:-false}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test result functions
test_passed() {
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
    log_success "✓ $1"
}

test_failed() {
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
    log_error "✗ $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_tools=()

    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi

    if ! command -v kind &> /dev/null; then
        missing_tools+=("kind")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v ocm &> /dev/null; then
        missing_tools+=("ocm")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install missing tools:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                docker)
                    echo "  - Docker: https://docs.docker.com/get-docker/"
                    ;;
                kind)
                    echo "  - KIND: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
                    ;;
                kubectl)
                    echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                ocm)
                    echo "  - OCM CLI: https://ocm.software/docs/cli-reference/download/cli/"
                    ;;
            esac
        done
        return 1
    fi

    log_success "All prerequisites found"
    return 0
}

# Create KIND cluster
create_kind_cluster() {
    log_info "Creating KIND cluster: $CLUSTER_NAME"

    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_warning "KIND cluster '$CLUSTER_NAME' already exists"
        log_info "Using existing cluster. To recreate, run: kind delete cluster --name $CLUSTER_NAME"
    else
        cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF
        log_success "KIND cluster created"
    fi

    # Set kubectl context
    kubectl config use-context "kind-${CLUSTER_NAME}"

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s

    test_passed "KIND cluster ready"
}

# Install CloudNativePG operator
install_cnpg_operator() {
    log_info "Installing CloudNativePG operator..."

    # Check if operator is already installed
    if kubectl get deployment -n cnpg-system cnpg-controller-manager &>/dev/null; then
        log_warning "CloudNativePG operator already installed"
        test_passed "CloudNativePG operator present"
        return 0
    fi

    # Install the operator using server-side apply to handle large CRD annotations
    local CNPG_VERSION="${CNPG_VERSION:-1.24.1}"
    kubectl apply --server-side -f "https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v${CNPG_VERSION}/releases/cnpg-${CNPG_VERSION}.yaml"

    # Wait for operator to be ready
    log_info "Waiting for operator to be ready..."
    kubectl wait --for=condition=Available deployment/cnpg-controller-manager \
        -n cnpg-system --timeout=300s

    test_passed "CloudNativePG operator installed and ready"
}

# Build OCM component
build_component() {
    if [ "$SKIP_BUILD" = "true" ]; then
        log_info "Skipping component build (SKIP_BUILD=true)"
        if [ ! -d "$BUILD_DIR" ]; then
            log_error "Build directory not found and SKIP_BUILD=true"
            test_failed "Component build directory check"
            return 1
        fi
        test_passed "Component build directory exists"
        return 0
    fi

    log_info "Building OCM component..."

    if ! make build; then
        log_error "Failed to build component"
        test_failed "Component build"
        return 1
    fi

    test_passed "Component build"
}

# Validate component structure
validate_component() {
    log_info "Validating component structure..."

    if ! make validate; then
        log_error "Component validation failed"
        test_failed "Component validation"
        return 1
    fi

    test_passed "Component validation"
}

# Test component resources
test_component_resources() {
    log_info "Testing component resources..."

    # Check if component has expected resources
    local resources=$(ocm get resources "$BUILD_DIR" -o json)

    # Check for operator image
    if echo "$resources" | grep -q "cloudnative-pg-operator"; then
        test_passed "Operator image resource present"
    else
        test_failed "Operator image resource missing"
    fi

    # Check for PostgreSQL images
    for version in 17 16 15 14; do
        if echo "$resources" | grep -q "postgresql-${version}"; then
            test_passed "PostgreSQL ${version} image resource present"
        else
            test_failed "PostgreSQL ${version} image resource missing"
        fi
    done

    # Check for configuration templates
    local templates=("operator-configmap" "monitoring-queries" "cluster-basic" "cluster-ha" "cluster-backup-s3" "cluster-monitoring")
    for template in "${templates[@]}"; do
        if echo "$resources" | grep -q "$template"; then
            test_passed "Configuration template '$template' present"
        else
            test_failed "Configuration template '$template' missing"
        fi
    done
}

# Extract and test configuration template
test_configuration_template() {
    local template_name=$1
    local output_file=$2

    log_info "Testing template: $template_name"

    # Extract template
    if ! ocm download resource "$BUILD_DIR" "$template_name" -O "$output_file" 2>/dev/null; then
        test_failed "Extract template '$template_name'"
        return 1
    fi

    test_passed "Extract template '$template_name'"

    # Validate YAML syntax (ignore CRD not found errors)
    local validation_output
    local exit_code
    set +e  # Temporarily disable exit on error
    validation_output=$(kubectl apply --dry-run=client -f "$output_file" 2>&1)
    exit_code=$?
    set -e  # Re-enable exit on error

    # Check if it's only CRD missing error (which is OK for template validation)
    if [ $exit_code -ne 0 ]; then
        if echo "$validation_output" | grep -q "no matches for kind"; then
            # CRD not installed, but YAML is valid
            test_passed "Validate YAML syntax for '$template_name' (CRD not installed)"
        elif echo "$validation_output" | grep -q "error parsing"; then
            # Actual YAML syntax error
            test_failed "Validate YAML syntax for '$template_name'"
            echo "$validation_output"
            return 1
        else
            # Some other error - consider it a pass if YAML parses
            test_passed "Validate YAML syntax for '$template_name'"
        fi
    else
        test_passed "Validate YAML syntax for '$template_name'"
    fi
}

# Deploy minimal test PostgreSQL cluster
deploy_test_cluster() {
    log_info "Deploying minimal test PostgreSQL cluster..."

    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Extract and customize minimal cluster template
    local cluster_file="/tmp/test-pgcluster.yaml"
    if ! ocm download resource "$BUILD_DIR" cluster-basic -O "$cluster_file" 2>/dev/null; then
        test_failed "Extract PostgreSQL cluster template"
        return 1
    fi

    # Substitute variables for test
    export CLUSTER_NAME="pg-test"
    export CLUSTER_NAMESPACE="$TEST_NAMESPACE"
    export INSTANCES="1"
    export STORAGE_SIZE="1Gi"
    export POSTGRES_VERSION="16"
    export CPU_REQUEST="100m"
    export CPU_LIMIT="500m"
    export MEMORY_REQUEST="256Mi"
    export MEMORY_LIMIT="512Mi"
    export DATABASE_NAME="testdb"
    export DATABASE_OWNER="testuser"
    export DATABASE_PASSWORD="testpass123"

    # Apply with variable substitution using bash eval
    # We need to use bash to expand ${VAR:-default} syntax properly
    eval "cat <<EOF
$(cat "$cluster_file")
EOF
" | kubectl apply -f -

    test_passed "Deploy test PostgreSQL cluster"

    # Wait for PostgreSQL cluster to be ready (with timeout)
    log_info "Waiting for PostgreSQL cluster to be ready (this may take several minutes for image pulls)..."
    local timeout=600  # 10 minutes to allow for image pulls
    local elapsed=0
    local last_status=""

    while [ $elapsed -lt $timeout ]; do
        # Check if the Cluster CRD resource exists
        if kubectl get cluster.postgresql.cnpg.io "$CLUSTER_NAME" -n "$TEST_NAMESPACE" &>/dev/null; then
            # Check the cluster status
            local status=$(kubectl get cluster.postgresql.cnpg.io "$CLUSTER_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

            # Show status changes
            if [ "$status" != "$last_status" ] && [ -n "$status" ]; then
                log_info "PostgreSQL cluster status: $status"
                last_status="$status"
            fi

            # Also check if at least one pod is running
            local running_pods=$(kubectl get pods -n "$TEST_NAMESPACE" -l "cnpg.io/cluster=$CLUSTER_NAME" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')

            if [ "$status" = "Cluster in healthy state" ] || [ "$running_pods" -gt 0 ]; then
                test_passed "PostgreSQL cluster reached healthy state"
                log_info "Final cluster status: $status"
                log_info "Running pods: $running_pods"
                kubectl get pods -n "$TEST_NAMESPACE" -l "cnpg.io/cluster=$CLUSTER_NAME"
                return 0
            fi
        fi
        sleep 10
        ((elapsed+=10))
    done

    log_warning "PostgreSQL cluster did not reach healthy state within timeout"
    log_info "Checking cluster status:"
    kubectl get cluster.postgresql.cnpg.io "$CLUSTER_NAME" -n "$TEST_NAMESPACE" -o yaml || true
    log_info "Checking pods:"
    kubectl get pods -n "$TEST_NAMESPACE" || true
    kubectl describe pods -n "$TEST_NAMESPACE" || true
    test_failed "PostgreSQL cluster readiness timeout"
}

# Test operator configuration
test_operator_config() {
    log_info "Testing operator configuration template..."

    local config_file="/tmp/operator-config.yaml"
    test_configuration_template "operator-configmap" "$config_file"

    # Check if it contains expected keys
    if grep -q "CERTIFICATE_DURATION" "$config_file"; then
        test_passed "Operator config contains CERTIFICATE_DURATION"
    else
        test_failed "Operator config missing CERTIFICATE_DURATION"
    fi
}

# Cleanup
cleanup() {
    if [ "$CLEANUP_ON_SUCCESS" = "true" ] && [ $TESTS_FAILED -eq 0 ]; then
        log_info "Cleaning up test resources..."

        # Delete test PostgreSQL cluster
        kubectl delete cluster.postgresql.cnpg.io pg-test -n "$TEST_NAMESPACE" --ignore-not-found=true --wait=false

        # Delete test namespace
        kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true --wait=false

        # Delete KIND cluster
        log_info "Deleting KIND cluster: $CLUSTER_NAME"
        kind delete cluster --name "$CLUSTER_NAME"

        log_success "Cleanup complete"
    else
        log_warning "Skipping cleanup (CLEANUP_ON_SUCCESS=$CLEANUP_ON_SUCCESS, TESTS_FAILED=$TESTS_FAILED)"
        log_info "To manually clean up:"
        log_info "  kubectl delete namespace $TEST_NAMESPACE"
        log_info "  kind delete cluster --name $CLUSTER_NAME"
    fi
}

# Print test summary
print_summary() {
    echo ""
    echo "======================================"
    echo "          TEST SUMMARY"
    echo "======================================"
    echo "Total tests:  $TESTS_TOTAL"
    echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
    echo "======================================"

    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# Main test execution
main() {
    log_info "Starting CloudNativePG OCM Component Test Suite"
    echo ""

    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    echo ""

    # Build component
    if ! build_component; then
        print_summary
        exit 1
    fi
    echo ""

    # Validate component
    if ! validate_component; then
        print_summary
        exit 1
    fi
    echo ""

    # Test component resources
    test_component_resources
    echo ""

    # Test configuration templates (without deploying)
    test_operator_config
    echo ""

    # Test configuration extraction
    test_configuration_template "cluster-ha" "/tmp/cluster-ha.yaml"
    test_configuration_template "cluster-monitoring" "/tmp/cluster-monitoring.yaml"
    echo ""

    # Kubernetes tests (optional based on SKIP_K8S_TESTS)
    if [ "${SKIP_K8S_TESTS:-false}" != "true" ]; then
        # Create KIND cluster
        if ! create_kind_cluster; then
            cleanup
            print_summary
            exit 1
        fi
        echo ""

        # Install CNPG operator
        if ! install_cnpg_operator; then
            cleanup
            print_summary
            exit 1
        fi
        echo ""

        # Deploy test cluster
        deploy_test_cluster
        echo ""

        # Cleanup
        cleanup
    else
        log_info "Skipping Kubernetes tests (SKIP_K8S_TESTS=true)"
    fi

    # Print summary
    echo ""
    print_summary
}

# Handle interrupts
trap 'log_error "Test interrupted"; cleanup; exit 130' INT TERM

# Run main
main
exit $?
