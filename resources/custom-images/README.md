# Custom PostgreSQL Images

This directory contains Dockerfiles and build scripts for creating custom PostgreSQL images with additional extensions.

## Available Images

### TimescaleDB
**File**: `Dockerfile.timescaledb`

PostgreSQL with TimescaleDB extension for time-series data.

**Build**:
```bash
make build-timescaledb PG_VERSION=16
```

**Use**:
```yaml
spec:
  imageName: my-registry.com/postgresql-timescaledb:16
  bootstrap:
    initdb:
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS timescaledb;
```

### pgvector
**File**: `Dockerfile.pgvector`

PostgreSQL with pgvector extension for vector similarity search and AI/ML workloads.

**Build**:
```bash
make build-pgvector PG_VERSION=16 PGVECTOR_VERSION=0.5.1
```

**Use**:
```yaml
spec:
  imageName: my-registry.com/postgresql-pgvector:16
  bootstrap:
    initdb:
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS vector;
```

## Building Images

### Prerequisites
- Docker installed
- Access to push to your container registry
- Base CloudNativePG images available

### Build All Images
```bash
make build-all REGISTRY=my-registry.com PG_VERSION=16
```

### Build Specific Image
```bash
# TimescaleDB
make build-timescaledb REGISTRY=my-registry.com PG_VERSION=16

# pgvector
make build-pgvector REGISTRY=my-registry.com PG_VERSION=16 PGVECTOR_VERSION=0.5.1
```

### Push to Registry
```bash
# Push all
make push-all REGISTRY=my-registry.com

# Push specific
make push-timescaledb REGISTRY=my-registry.com
make push-pgvector REGISTRY=my-registry.com
```

### Test Images
```bash
make test-timescaledb REGISTRY=my-registry.com
make test-pgvector REGISTRY=my-registry.com
```

## Using Custom Images in OCM

After building and pushing your custom images, add them to the OCM component:

### Option 1: Override at Deployment Time

Use the `IMAGE_NAME` variable in cluster templates:

```bash
export IMAGE_NAME="my-registry.com/postgresql-timescaledb:16"
envsubst < cluster.yaml | kubectl apply -f -
```

### Option 2: Add to Component Descriptor

Add custom images as resources in `component-constructor.yaml`:

```yaml
resources:
  - name: postgresql-timescaledb
    type: ociImage
    version: "${PG_VERSION}"
    relation: external
    access:
      type: ociArtifact
      imageReference: my-registry.com/postgresql-timescaledb:${PG_VERSION}
    labels:
      - name: "cnpg.io/component-type"
        value: "postgresql"
      - name: "cnpg.io/extensions"
        value: "timescaledb"
```

## Multi-Architecture Builds

To build multi-architecture images (amd64, arm64):

```bash
# Create and use buildx builder
docker buildx create --name multiarch --use

# Build and push multi-arch TimescaleDB
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg PG_VERSION=16 \
  -t my-registry.com/postgresql-timescaledb:16 \
  -f Dockerfile.timescaledb \
  --push \
  .

# Build and push multi-arch pgvector
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg PG_VERSION=16 \
  --build-arg PGVECTOR_VERSION=0.5.1 \
  -t my-registry.com/postgresql-pgvector:16 \
  -f Dockerfile.pgvector \
  --push \
  .
```

## Image Size Optimization

Tips for reducing image size:

1. **Multi-stage builds**: Separate build and runtime stages
2. **Minimal dependencies**: Only install required packages
3. **Clean up**: Remove build tools and apt cache
4. **Layer optimization**: Combine RUN commands

Example optimized Dockerfile pattern:
```dockerfile
RUN set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends build-deps && \
    # Build extension \
    apt-get remove -y build-deps && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

## Security Scanning

Scan images for vulnerabilities before deployment:

```bash
# Using Trivy
trivy image my-registry.com/postgresql-timescaledb:16

# Using Docker Scout
docker scout cves my-registry.com/postgresql-timescaledb:16

# Using Grype
grype my-registry.com/postgresql-timescaledb:16
```

## Creating Your Own Extension Image

Template for adding a new extension:

```dockerfile
ARG PG_VERSION=16
FROM ghcr.io/cloudnative-pg/postgresql:${PG_VERSION}

USER root

# Install your extension
RUN set -ex && \
    apt-get update && \
    apt-get install -y your-extension-package && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure if needed
RUN echo "shared_preload_libraries = 'your_extension'" >> \
    /usr/share/postgresql/postgresql.conf.sample

USER 26

LABEL cnpg.io/extensions="your-extension"
LABEL cnpg.io/extension-type="your-category"
```

## Best Practices

1. **Version pinning**: Always specify exact versions for extensions
2. **Minimal layers**: Combine related operations in single RUN commands
3. **User context**: Always switch back to `USER 26` (postgres)
4. **Labels**: Add descriptive labels for OCM and documentation
5. **Testing**: Test images thoroughly before production use
6. **Documentation**: Document extension configuration requirements
7. **Security**: Regularly update base images and scan for vulnerabilities

## Troubleshooting

### Build Failures

**Problem**: Package not found during apt-get install

**Solution**: Check package availability for your PostgreSQL version:
```bash
apt-cache policy postgresql-16-extension-name
```

### Extension Not Loading

**Problem**: Extension fails to load after deployment

**Solution**: Check if `shared_preload_libraries` is set correctly:
```sql
SHOW shared_preload_libraries;
```

### Permission Issues

**Problem**: Permission denied errors in container

**Solution**: Ensure you switch back to `USER 26` after installation steps.

## References

- [CloudNativePG Custom Images](https://cloudnative-pg.io/documentation/current/container_images/)
- [PostgreSQL Docker Official Images](https://hub.docker.com/_/postgres)
- [Docker Multi-Platform Builds](https://docs.docker.com/build/building/multi-platform/)
