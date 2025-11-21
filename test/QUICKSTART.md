# Test Quick Start

## Prerequisites

Install required tools:

```bash
# macOS
brew install docker kind kubectl
brew install open-component-model/tap/ocm

# Linux
# Install Docker: https://docs.docker.com/engine/install/
# Install KIND: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
# Install kubectl: https://kubernetes.io/docs/tasks/tools/
# Install OCM: https://ocm.software/docs/cli-reference/download/cli/
```

## Quick Test (30 seconds)

No Kubernetes required:

```bash
make test-quick
```

Tests:
- ✓ Component builds
- ✓ Component validates
- ✓ All resources present
- ✓ Templates extract correctly

## Full Test (5-10 minutes)

Requires Docker running:

```bash
make test
```

Tests:
- ✓ Everything from quick test
- ✓ KIND cluster creation
- ✓ CloudNativePG operator installation
- ✓ Test cluster deployment
- ✓ Cluster health verification

## Individual Tests

```bash
# Component only
make test-component

# Templates only
make test-templates

# Kubernetes only
make test-kind

# Debug (keep cluster)
make test-kind-keep
kubectl get all -n cnpg-test
make test-clean
```

## Common Issues

### Docker not running
```bash
# Start Docker Desktop or service
# macOS/Windows: Open Docker Desktop
# Linux: sudo systemctl start docker
```

### Port conflicts
```bash
# Delete existing cluster
kind delete cluster --name cnpg-test
```

### Test failure investigation
```bash
# Keep cluster for debugging
CLEANUP_ON_SUCCESS=false make test

# Inspect resources
kubectl get all -n cnpg-test
kubectl describe cluster pg-test -n cnpg-test

# Cleanup when done
make test-clean
```

## Environment Variables

```bash
# Custom cluster name
KIND_CLUSTER_NAME=my-test make test

# Skip build
SKIP_BUILD=true make test

# Skip Kubernetes tests
SKIP_K8S_TESTS=true make test

# Keep resources after success
CLEANUP_ON_SUCCESS=false make test
```

## Success Output

```
[INFO] Starting CloudNativePG OCM Component Test Suite
[SUCCESS] ✓ All prerequisites found
[SUCCESS] ✓ Component build
[SUCCESS] ✓ Component validation
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

## Next Steps

- See [test/README.md](README.md) for detailed documentation
- See [docs/configuration-guide.md](../docs/configuration-guide.md) for configuration options
- See [CLAUDE.md](../CLAUDE.md) for development guide
