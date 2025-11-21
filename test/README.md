# CloudNativePG OCM Component Test Suite

Comprehensive testing framework for validating the CloudNativePG OCM component.

## Overview

The test suite validates:

1. **Component Build** - OCM component builds successfully
2. **Component Structure** - All expected resources are present
3. **Configuration Templates** - Templates extract and validate correctly
4. **Kubernetes Deployment** - Templates deploy successfully in a live cluster
5. **Operator Integration** - CloudNativePG operator works with configurations

## Prerequisites

### Required Tools

- **Docker** - For running KIND clusters
  - Install: https://docs.docker.com/get-docker/
- **KIND** (Kubernetes IN Docker) - Local Kubernetes clusters
  - Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
- **kubectl** - Kubernetes CLI
  - Install: https://kubernetes.io/docs/tasks/tools/
- **OCM CLI** - Open Component Model CLI
  - Install: https://ocm.software/docs/cli-reference/download/cli/

### Optional Tools

- **envsubst** - For variable substitution (usually included in gettext package)

## Test Targets

### Complete Test Suite

```bash
make test
```

Runs the complete test suite including:
- Component build and validation
- Resource structure verification
- Configuration template extraction
- KIND cluster creation
- CloudNativePG operator installation
- Test cluster deployment
- Automatic cleanup

**Duration:** ~5-10 minutes (depending on download speeds)

### Quick Tests (No Kubernetes)

```bash
make test-quick
```

Runs only component validation tests, skipping Kubernetes deployment:
- Component build
- Component validation
- Resource presence check
- Template extraction
- YAML syntax validation

**Duration:** ~30 seconds

### Component Structure Test

```bash
make test-component
```

Tests component build and structure:
- Builds the component
- Validates component descriptor
- Checks resource list

**Duration:** ~20 seconds

### Template Validation Test

```bash
make test-templates
```

Extracts and validates all configuration templates:
- Extracts each template from the component
- Validates YAML syntax with kubectl dry-run
- Tests all 8 configuration templates

**Duration:** ~30 seconds

### Kubernetes Integration Tests

```bash
make test-kind
```

Full Kubernetes testing with automatic cleanup:
- Creates KIND cluster
- Installs CloudNativePG operator
- Deploys test cluster
- Validates cluster health
- Cleans up all resources

**Duration:** ~5-10 minutes

### Kubernetes Tests (Keep Cluster)

```bash
make test-kind-keep
```

Same as `test-kind` but keeps the cluster running for debugging:
- Useful for inspecting failed deployments
- Cluster name: `cnpg-test`
- Manual cleanup: `make test-clean`

### Clean Test Resources

```bash
make test-clean
```

Removes all test artifacts:
- Deletes KIND cluster
- Removes temporary files

## Environment Variables

### Test Configuration

- `KIND_CLUSTER_NAME` - KIND cluster name (default: `cnpg-test`)
- `CLEANUP_ON_SUCCESS` - Clean up after successful tests (default: `true`)
- `SKIP_BUILD` - Skip component build step (default: `false`)
- `SKIP_K8S_TESTS` - Skip Kubernetes deployment tests (default: `false`)

### Examples

```bash
# Use custom cluster name
KIND_CLUSTER_NAME=my-test make test-kind

# Keep cluster even on success
CLEANUP_ON_SUCCESS=false make test

# Skip build if already built
SKIP_BUILD=true make test

# Only run component tests
SKIP_K8S_TESTS=true make test
```

## Test Script Details

### test-suite.sh

Main test script that orchestrates all tests.

**Features:**
- Colored output for better visibility
- Test pass/fail tracking
- Detailed error reporting
- Graceful interruption handling
- Comprehensive logging

**Test Categories:**

1. **Prerequisites Check**
   - Verifies all required tools are installed
   - Provides installation links for missing tools

2. **Component Tests**
   - Builds OCM component
   - Validates component descriptor
   - Checks for all expected resources (5 images + 8 templates)

3. **Template Tests**
   - Extracts configuration templates
   - Validates YAML syntax
   - Checks for required configuration keys

4. **Kubernetes Tests**
   - Creates multi-node KIND cluster (1 control-plane + 2 workers)
   - Installs CloudNativePG operator
   - Deploys minimal test cluster
   - Waits for cluster to reach healthy state
   - Validates pod status

**Exit Codes:**
- `0` - All tests passed
- `1` - Test failures occurred
- `130` - Tests interrupted by user

## Test Results

### Success Output

```
[INFO] Starting CloudNativePG OCM Component Test Suite
[SUCCESS] ✓ All prerequisites found
[SUCCESS] ✓ Component build
[SUCCESS] ✓ Component validation
[SUCCESS] ✓ Operator image resource present
[SUCCESS] ✓ PostgreSQL 17 image resource present
...
======================================
          TEST SUMMARY
======================================
Total tests:  15
Passed:       15
Failed:       0
======================================
[SUCCESS] All tests passed!
```

### Failure Output

```
[ERROR] ✗ Component build
[ERROR] Some tests failed

======================================
          TEST SUMMARY
======================================
Total tests:  10
Passed:       8
Failed:       2
======================================
```

## Troubleshooting

### Docker Not Running

**Error:** `Cannot connect to the Docker daemon`

**Solution:**
```bash
# Start Docker Desktop (macOS/Windows)
# Or start Docker service (Linux)
sudo systemctl start docker
```

### KIND Cluster Creation Fails

**Error:** `failed to create cluster`

**Solution:**
```bash
# Clean up existing clusters
kind delete cluster --name cnpg-test

# Check Docker resources
docker system df
docker system prune  # If needed
```

### OCM CLI Not Found

**Error:** `ocm: command not found`

**Solution:**
```bash
# macOS
brew install open-component-model/tap/ocm

# Linux
curl -LO https://github.com/open-component-model/ocm/releases/latest/download/ocm-linux-amd64
chmod +x ocm-linux-amd64
sudo mv ocm-linux-amd64 /usr/local/bin/ocm
```

### Test Cluster Not Ready

**Error:** `Cluster readiness timeout`

**Debug:**
```bash
# Keep cluster for inspection
CLEANUP_ON_SUCCESS=false make test-kind

# Check cluster status
kubectl get cluster pg-test -n cnpg-test -o yaml

# Check pods
kubectl get pods -n cnpg-test

# Check operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg

# Cleanup when done
make test-clean
```

### Template Extraction Fails

**Error:** `Failed to extract template`

**Debug:**
```bash
# Build component
make build

# List resources
ocm get resources ./build

# Try manual extraction
ocm download resource ./build cluster-basic -O /tmp/test.yaml
cat /tmp/test.yaml
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test OCM Component

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install OCM CLI
        run: |
          curl -LO https://github.com/open-component-model/ocm/releases/latest/download/ocm-linux-amd64
          chmod +x ocm-linux-amd64
          sudo mv ocm-linux-amd64 /usr/local/bin/ocm

      - name: Run tests
        run: make test
```

### GitLab CI Example

```yaml
test:
  image: ubuntu:latest
  services:
    - docker:dind
  before_script:
    - apt-get update && apt-get install -y curl docker.io kubectl
    - curl -LO https://github.com/open-component-model/ocm/releases/latest/download/ocm-linux-amd64
    - chmod +x ocm-linux-amd64 && mv ocm-linux-amd64 /usr/local/bin/ocm
    - curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
    - chmod +x ./kind && mv ./kind /usr/local/bin/kind
  script:
    - make test
```

## Development Workflow

### Running Tests During Development

```bash
# 1. Quick validation after changes
make test-quick

# 2. Validate templates
make test-templates

# 3. Full test before commit
make test

# 4. Debug deployment issues
make test-kind-keep
kubectl get all -n cnpg-test
make test-clean
```

### Adding New Tests

1. Edit `test/test-suite.sh`
2. Add test function following naming convention: `test_*`
3. Use test result functions: `test_passed` or `test_failed`
4. Update test count
5. Run tests to verify

Example:
```bash
test_new_feature() {
    log_info "Testing new feature..."

    if [[ condition ]]; then
        test_passed "New feature works"
    else
        test_failed "New feature broken"
    fi
}
```

## Performance

### Test Duration

| Test Target | Duration | Network | Kubernetes |
|-------------|----------|---------|------------|
| `test-quick` | ~30s | Minimal | No |
| `test-component` | ~20s | Minimal | No |
| `test-templates` | ~30s | Minimal | No |
| `test-kind` | ~5-10min | Heavy | Yes |
| `test` | ~5-10min | Heavy | Yes |

### Optimization Tips

1. **Use Quick Tests During Development**
   ```bash
   make test-quick
   ```

2. **Keep KIND Cluster for Multiple Runs**
   ```bash
   make test-kind-keep
   # Make changes
   SKIP_BUILD=false make test  # Reuse cluster
   make test-clean  # When done
   ```

3. **Skip Build if Unchanged**
   ```bash
   SKIP_BUILD=true make test
   ```

## Best Practices

1. **Run Quick Tests Frequently** - Fast feedback loop
2. **Run Full Tests Before Commits** - Ensure no regressions
3. **Use KIND Keep for Debugging** - Inspect failed deployments
4. **Check Test Output** - Review failed tests carefully
5. **Clean Up After Tests** - Remove test clusters

## Support

For issues with:
- **Test failures** - Check test output and logs
- **KIND issues** - See KIND documentation
- **CloudNativePG issues** - See CloudNativePG documentation
- **OCM issues** - See OCM documentation
