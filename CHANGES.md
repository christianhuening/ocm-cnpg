# Air-Gapped Deployment Support

## Summary

Added support for deploying CloudNativePG in air-gapped environments by making deployment-time image references configurable through template variables.

## Changes Made

### 1. Configuration Templates Updated

All cluster configuration templates now support the `IMAGE_NAME` variable for specifying PostgreSQL images:

**Files Modified:**
- `config/cluster/basic-cluster.yaml`
- `config/cluster/ha-cluster.yaml`
- `config/cluster/backup-s3.yaml`
- `config/cluster/backup-gcs.yaml`
- `config/cluster/backup-azure.yaml`
- `config/cluster/monitoring.yaml`

**Change:**
```yaml
# Before
imageName: ghcr.io/cloudnative-pg/postgresql:${POSTGRES_VERSION:-16}

# After
imageName: ${IMAGE_NAME:-ghcr.io/cloudnative-pg/postgresql:${POSTGRES_VERSION:-16}}
```

This allows users to override the image at deployment time:
```bash
export IMAGE_NAME="my-airgap-registry.com/ocm/postgresql:16"
envsubst < cluster.yaml | kubectl apply -f -
```

### 2. Operator Configuration Enhanced

Updated `config/operator/operator-configmap.yaml` with documentation for air-gapped deployments:

- Added comments explaining `POSTGRES_IMAGE_NAME` usage in air-gapped environments
- Added comments explaining `OPERATOR_IMAGE_NAME` usage in air-gapped environments

### 3. Component Descriptor

**No changes to `component-constructor.yaml`** - correctly references upstream registries (`ghcr.io/cloudnative-pg/`). OCM handles image relocation automatically during `ocm transfer`.

### 4. Documentation Added

Created comprehensive documentation:

**[docs/AIR_GAPPED_DEPLOYMENT.md](docs/AIR_GAPPED_DEPLOYMENT.md)**
- Complete air-gapped deployment workflow
- OCM image relocation explanation
- Template variable usage
- Registry authentication setup
- Troubleshooting guide
- Complete working examples

**[docs/README.md](docs/README.md)**
- Documentation index
- Quick start guides
- Template reference
- Usage examples

**Updated [CLAUDE.md](CLAUDE.md)**
- Removed incorrect "Private Registry Configuration" section
- Added correct "Air-Gapped Deployment" section
- Updated examples to show OCM transfer and template configuration

### 5. Build System

**No changes to Makefile** - build process remains unchanged as source registries stay as upstream.

## How It Works

### Build Phase (Outside Air-Gap)
```bash
make build
# Creates component referencing ghcr.io/cloudnative-pg/* images
```

### Transfer Phase (OCM Relocates Images)
```bash
ocm transfer componentversions ./build airgap-registry.internal/ocm
# OCM automatically:
# 1. Copies all images to airgap-registry.internal/ocm/*
# 2. Updates component metadata with new locations
```

### Deployment Phase (Inside Air-Gap)
```bash
# Extract templates
ocm download resource airgap-registry.internal/ocm//ocm.software/cloudnative-pg:1.24.1 \
  cluster-basic -O cluster.yaml

# Configure for relocated images
export IMAGE_NAME="airgap-registry.internal/ocm/postgresql:16"
export POSTGRES_IMAGE_NAME="airgap-registry.internal/ocm/postgresql:16"
export OPERATOR_IMAGE_NAME="airgap-registry.internal/ocm/cloudnative-pg:1.24.1"

# Deploy
envsubst < operator-configmap.yaml | kubectl apply -f -
envsubst < cluster.yaml | kubectl apply -f -
```

## Key Principles

1. **Source registries unchanged**: Component descriptor always references official upstream registries
2. **OCM handles relocation**: `ocm transfer` automatically relocates images to target registry
3. **Templates are configurable**: Deployment manifests support variable substitution for relocated images
4. **Predictable paths**: Relocated images follow predictable patterns (e.g., `<registry>/<prefix>/postgresql:16`)

## Testing

To test air-gapped deployment:

```bash
# Build and transfer to a test registry
make build
ocm transfer componentversions ./build localhost:5000/test

# Extract templates
ocm download resource localhost:5000/test//ocm.software/cloudnative-pg:1.24.1 \
  cluster-basic -O test-cluster.yaml

# Verify IMAGE_NAME variable works
export IMAGE_NAME="localhost:5000/test/postgresql:16"
envsubst < test-cluster.yaml | grep imageName
# Should show: imageName: localhost:5000/test/postgresql:16
```

## Migration from Previous Approach

If using the previous incorrect approach with `OPERATOR_REGISTRY` and `POSTGRESQL_REGISTRY` variables in the build phase, migrate to:

1. Remove those variables from your build process
2. Use default `make build` (references upstream)
3. Configure image references at **deployment time** using `IMAGE_NAME`, `POSTGRES_IMAGE_NAME`, and `OPERATOR_IMAGE_NAME`
4. See [docs/AIR_GAPPED_DEPLOYMENT.md](docs/AIR_GAPPED_DEPLOYMENT.md) for complete examples

## Benefits

- ✅ Correct OCM pattern for air-gapped deployment
- ✅ Single build works for all environments (public, private, air-gapped)
- ✅ OCM automatically handles image relocation
- ✅ Deployment-time configuration is flexible and explicit
- ✅ Works with OCM's component transport and verification features
- ✅ Supports mixed environments (some components from different registries)
