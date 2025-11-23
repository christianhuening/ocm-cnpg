# Advanced Features

This document covers the advanced features available in the CloudNativePG OCM component.

## Overview

Phase 5 advanced features include:

1. **Multi-Architecture Support** - Deploy on different CPU architectures
2. **Configuration Validation** - JSON Schema validation for cluster configurations
3. **Component References** - Extension dependencies and relationships
4. **Custom PostgreSQL Images** - Build and use custom images with extensions

## 1. Multi-Architecture Support

All CloudNativePG images support multiple architectures out of the box.

### Supported Architectures

- **linux/amd64** - x86_64 processors (Intel, AMD)
- **linux/arm64** - ARM 64-bit (Apple Silicon, AWS Graviton, Ampere)
- **linux/ppc64le** - IBM POWER processors
- **linux/s390x** - IBM Z mainframes

### Architecture Information

The component descriptor includes architecture labels for all images:

```yaml
labels:
  - name: "architecture.ocm.io/platforms"
    value: "linux/amd64,linux/arm64,linux/ppc64le,linux/s390x"
```

### Using Specific Architectures

Docker/Kubernetes automatically selects the correct architecture for your nodes. To verify:

```bash
# Check node architecture
kubectl get nodes -o wide

# Verify pod is running on correct architecture
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeSelector}'
```

### Multi-Arch Air-Gapped Deployment

When transferring to air-gapped environments, OCM transfers all architectures:

```bash
# Transfer includes all architectures
ocm transfer componentversions ./build airgap-registry.internal/ocm

# Verify all architectures were transferred
crane manifest airgap-registry.internal/ocm/postgresql:16 | jq '.manifests[].platform'
```

### Node Affinity for Specific Architectures

To deploy on specific architectures:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: arm-cluster
spec:
  instances: 3
  imageName: my-registry.com/postgresql:16

  # Deploy only on ARM64 nodes
  nodeSelector:
    kubernetes.io/arch: arm64

  # Or use affinity for more complex rules
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                  - arm64
```

## 2. Configuration Validation

The component includes a JSON Schema for validating cluster configurations before deployment.

### Schema Location

The cluster validation schema is included as a resource:

```bash
# Extract the schema
ocm download resource <component> cluster-schema -O cluster-schema.json
```

### Using the Schema

#### Option 1: Command-Line Validation

Using `ajv-cli` or similar tools:

```bash
# Install ajv-cli
npm install -g ajv-cli

# Validate a cluster configuration
ajv validate -s cluster-schema.json -d my-cluster.yaml
```

#### Option 2: IDE Integration

Most modern IDEs support JSON Schema validation for YAML files.

**VS Code** (`settings.json`):
```json
{
  "yaml.schemas": {
    "./cluster-schema.json": ["**/cluster*.yaml", "**/pg-*.yaml"]
  }
}
```

**IntelliJ/PyCharm**:
1. Preferences → Languages & Frameworks → Schemas and DTDs
2. Add → JSON Schema
3. Associate with file patterns

#### Option 3: CI/CD Pipeline

```yaml
# GitHub Actions example
- name: Validate Cluster Configurations
  run: |
    ocm download resource $COMPONENT cluster-schema -O schema.json
    for file in config/clusters/*.yaml; do
      ajv validate -s schema.json -d "$file" || exit 1
    done
```

### Schema Features

The cluster schema validates:

- **Required fields**: `apiVersion`, `kind`, `metadata.name`, `spec.instances`
- **Instance count**: 1-100 instances
- **Image references**: Valid container image format
- **Resource limits**: Valid CPU and memory formats
- **Storage sizes**: Valid Kubernetes quantity format
- **Backup configuration**: Valid destination paths and retention policies
- **PostgreSQL parameters**: Type checking for common parameters

### Example Validation Errors

```bash
$ ajv validate -s cluster-schema.json -d bad-cluster.yaml

cluster.yaml invalid
[
  {
    "instancePath": "/spec/instances",
    "message": "must be integer",
    "keyword": "type",
    "params": {"type": "integer"}
  },
  {
    "instancePath": "/spec/storage/size",
    "message": "must match pattern \"^[0-9]+(\\.[0-9]+)?(Ei|Pi|Ti|Gi|Mi|Ki)?$\"",
    "keyword": "pattern"
  }
]
```

### Custom Schema Extensions

You can extend the base schema for your organization's requirements:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "allOf": [
    { "$ref": "cluster-schema.json" },
    {
      "properties": {
        "metadata": {
          "properties": {
            "labels": {
              "required": ["team", "environment", "cost-center"]
            }
          }
        }
      }
    }
  ]
}
```

## 3. Component References

The component includes references to optional PostgreSQL extensions and related components.

### Included References

#### PostGIS
Geospatial extension for PostgreSQL:

```yaml
componentReferences:
  - name: postgis
    componentName: ghcr.io/cloudnative-pg/postgis
    version: "16-3.4"
    labels:
      - name: "cnpg.io/extension-type"
        value: "geospatial"
```

### Querying Component References

```bash
# List all component references
ocm get componentversion <component> -o yaml | grep -A 10 componentReferences

# Get details about a specific reference
ocm get componentversion ghcr.io/cloudnative-pg/postgis:16-3.4
```

### Using Referenced Components

To use PostGIS from the component reference:

```bash
# Resolve the component reference
ocm get componentversion <component> --lookup postgis

# Download PostGIS image reference
ocm get resource ghcr.io/cloudnative-pg/postgis:16-3.4
```

Then use in your cluster:

```yaml
spec:
  imageName: ghcr.io/cloudnative-pg/postgis:16-3.4
  bootstrap:
    initdb:
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS postgis;
        - CREATE EXTENSION IF NOT EXISTS postgis_topology;
```

### Adding Custom Extension References

You can add your own extension components:

```yaml
# In component-constructor.yaml
componentReferences:
  - name: my-custom-extension
    componentName: my-registry.com/postgresql-extensions/custom
    version: "1.0.0"
    labels:
      - name: "cnpg.io/extension-type"
        value: "custom"
      - name: "cnpg.io/extension-category"
        value: "analytics"
```

### Extension Dependencies

Component references can express dependencies between extensions:

```yaml
componentReferences:
  - name: postgis
    componentName: ghcr.io/cloudnative-pg/postgis
    version: "16-3.4"

  - name: postgis-raster
    componentName: my-registry.com/postgis-raster
    version: "3.4.0"
    # This extension requires PostGIS
    extraIdentity:
      requires: "postgis"
```

## 4. Custom PostgreSQL Images

Build and use custom PostgreSQL images with additional extensions.

### Available Templates

The component includes Dockerfiles for common extensions:

1. **TimescaleDB** - Time-series database
2. **pgvector** - Vector similarity search for AI/ML

### Building Custom Images

```bash
cd resources/custom-images

# Build TimescaleDB image
make build-timescaledb \
  REGISTRY=my-registry.com \
  PG_VERSION=16

# Build pgvector image
make build-pgvector \
  REGISTRY=my-registry.com \
  PG_VERSION=16 \
  PGVECTOR_VERSION=0.5.1

# Push to registry
make push-all REGISTRY=my-registry.com
```

### Multi-Architecture Custom Images

```bash
# Create buildx builder
docker buildx create --name multiarch --use

# Build and push multi-arch image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg PG_VERSION=16 \
  -t my-registry.com/postgresql-timescaledb:16 \
  -f Dockerfile.timescaledb \
  --push \
  .
```

### Using Custom Images

#### In Cluster Configuration

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: timeseries-db
spec:
  instances: 3
  imageName: my-registry.com/postgresql-timescaledb:16

  bootstrap:
    initdb:
      database: metrics
      owner: app
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS timescaledb;
      postInitApplicationSQL:
        - SELECT create_hypertable('metrics', 'time');
```

#### With OCM Component

Add custom images to the component descriptor:

```yaml
resources:
  - name: postgresql-timescaledb
    type: ociImage
    version: "16"
    relation: external
    access:
      type: ociArtifact
      imageReference: my-registry.com/postgresql-timescaledb:16
    labels:
      - name: "architecture.ocm.io/platforms"
        value: "linux/amd64,linux/arm64"
      - name: "cnpg.io/component-type"
        value: "postgresql"
      - name: "cnpg.io/extensions"
        value: "timescaledb"
      - name: "cnpg.io/extension-type"
        value: "timeseries"
```

### Creating New Extension Images

Template for new extensions:

```dockerfile
ARG PG_VERSION=16
FROM ghcr.io/cloudnative-pg/postgresql:${PG_VERSION}

USER root

# Install extension
RUN apt-get update && \
    apt-get install -y postgresql-${PG_VERSION}-your-extension && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure if needed
RUN echo "shared_preload_libraries = 'your_extension'" >> \
    /usr/share/postgresql/postgresql.conf.sample

USER 26

LABEL cnpg.io/extensions="your-extension"
LABEL cnpg.io/extension-type="your-category"
```

See [resources/custom-images/README.md](../resources/custom-images/README.md) for detailed instructions.

## Best Practices

### Multi-Architecture

1. Test on all target architectures before production
2. Use multi-arch images for portability
3. Consider performance differences between architectures
4. Monitor resource usage per architecture

### Configuration Validation

1. Integrate schema validation in CI/CD pipelines
2. Validate before applying to clusters
3. Use IDE integration for early feedback
4. Extend schema for organization-specific requirements

### Component References

1. Version pin all component references
2. Document dependencies between components
3. Test referenced components before deployment
4. Use component references for extension discovery

### Custom Images

1. Keep custom images minimal
2. Scan for vulnerabilities regularly
3. Version pin all extension packages
4. Document extension configuration requirements
5. Test thoroughly before production use
6. Build multi-architecture images when possible

## Troubleshooting

### Multi-Architecture Issues

**Problem**: Pod stuck in `ImagePullBackOff` on ARM node

**Solution**: Verify the image includes ARM64 architecture:
```bash
crane manifest <image> | jq '.manifests[].platform'
```

### Schema Validation

**Problem**: Schema validation fails but YAML is correct

**Solution**: Ensure you're using the correct schema version and check for trailing whitespace or special characters.

### Component References

**Problem**: Cannot resolve component reference

**Solution**: Verify the referenced component exists:
```bash
ocm get componentversion <component-name>:<version>
```

### Custom Images

**Problem**: Extension fails to load

**Solution**: Check PostgreSQL logs for specific error messages:
```bash
kubectl logs <pod-name> | grep -i extension
```

## References

- [CloudNativePG Multi-Architecture](https://cloudnative-pg.io/documentation/current/architecture/)
- [JSON Schema Documentation](https://json-schema.org/)
- [OCM Component References](https://ocm.software/)
- [PostgreSQL Extensions](https://www.postgresql.org/docs/current/external-extensions.html)
