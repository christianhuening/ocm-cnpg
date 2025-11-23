# CloudNativePG OCM Component Documentation

This directory contains documentation for deploying and configuring the CloudNativePG OCM component.

## Documentation Index

### [Air-Gapped Deployment Guide](AIR_GAPPED_DEPLOYMENT.md)
Complete guide for deploying CloudNativePG in air-gapped environments. Covers:
- OCM component transfer and automatic image relocation
- Configuring deployment manifests for relocated images
- Registry authentication
- Complete deployment workflow examples
- Troubleshooting

### [Advanced Features](ADVANCED_FEATURES.md)
Advanced features and capabilities including:
- Multi-architecture support (amd64, arm64, ppc64le, s390x)
- Configuration validation with JSON Schema
- Component references for PostgreSQL extensions
- Building and using custom PostgreSQL images
- Extension management and best practices

## Quick Start

### Standard Deployment

```bash
# Build the component
make build

# Transfer to your OCM registry
ocm transfer componentversions ./build your-registry.com/ocm

# Extract and deploy manifests
ocm download resource your-registry.com/ocm//ocm.software/cloudnative-pg:1.24.1 \
  operator-configmap -O operator-configmap.yaml

kubectl apply -f operator-configmap.yaml
```

### Air-Gapped Deployment

```bash
# Build component (outside air-gap)
make build

# Transfer to air-gapped registry (OCM relocates images)
ocm transfer componentversions ./build airgap-registry.internal/ocm

# Inside air-gap: extract templates
ocm download resource airgap-registry.internal/ocm//ocm.software/cloudnative-pg:1.24.1 \
  cluster-basic -O cluster.yaml

# Configure for relocated images
export IMAGE_NAME="airgap-registry.internal/ocm/postgresql:16"
envsubst < cluster.yaml | kubectl apply -f -
```

See [AIR_GAPPED_DEPLOYMENT.md](AIR_GAPPED_DEPLOYMENT.md) for complete details.

## Configuration Templates

All configuration templates included in the OCM component:

### Operator Configuration
- **operator-configmap**: ConfigMap for operator settings (image defaults, timeouts, monitoring)
- **monitoring-queries**: Default PostgreSQL monitoring queries for Prometheus

### Cluster Templates
- **cluster-basic**: Minimal single-instance development cluster
- **cluster-ha**: Production-ready HA cluster with 3 instances
- **cluster-backup-s3**: Cluster with S3 backup configuration
- **cluster-backup-gcs**: Cluster with Google Cloud Storage backup
- **cluster-backup-azure**: Cluster with Azure Blob Storage backup
- **cluster-monitoring**: Cluster with full Prometheus monitoring

## Template Variables

All cluster templates support the following variables for air-gapped deployment:

| Variable | Description | Default |
|----------|-------------|---------|
| `IMAGE_NAME` | PostgreSQL container image | `ghcr.io/cloudnative-pg/postgresql:16` |
| `CLUSTER_NAME` | Name of the cluster | Template-specific default |
| `CLUSTER_NAMESPACE` | Kubernetes namespace | `default` |
| `INSTANCES` | Number of PostgreSQL instances | Varies by template |
| `STORAGE_SIZE` | Storage size per instance | Varies by template |
| `POSTGRES_VERSION` | PostgreSQL major version | `16` |

Operator configuration supports:

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_IMAGE_NAME` | Default PostgreSQL image for clusters | `ghcr.io/cloudnative-pg/postgresql:16` |
| `OPERATOR_IMAGE_NAME` | Operator image for bootstrapping | Auto-detected from deployment |

## Usage Examples

### Extract a Template

```bash
OCM_COMPONENT="your-registry.com/ocm//ocm.software/cloudnative-pg:1.24.1"

# List available resources
ocm get resources $OCM_COMPONENT

# Download specific template
ocm download resource $OCM_COMPONENT cluster-ha -O ha-cluster.yaml
```

### Apply with Variable Substitution

```bash
# Set variables
export CLUSTER_NAME="production-db"
export INSTANCES="5"
export STORAGE_SIZE="100Gi"
export IMAGE_NAME="airgap-registry.internal/ocm/postgresql:16"

# Apply with envsubst
envsubst < ha-cluster.yaml | kubectl apply -f -
```

### Direct Edit

```bash
# Download template
ocm download resource $OCM_COMPONENT cluster-basic -O my-cluster.yaml

# Edit the file
vim my-cluster.yaml

# Apply
kubectl apply -f my-cluster.yaml
```

## Additional Resources

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [OCM Documentation](https://ocm.software/)
- [Project CLAUDE.md](../CLAUDE.md) - Development and architecture guide
