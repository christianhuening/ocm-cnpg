# Using Private Registries

This document explains how to configure the OCM component to pull CloudNativePG images from private registries instead of the official ghcr.io repositories.

## Overview

The component supports configurable source registries for both the operator and PostgreSQL images. This allows you to:

- Use mirrored images from private registries
- Pull images from air-gapped environments
- Use organization-specific image repositories
- Mix and match registries (e.g., operator from one registry, PostgreSQL from another)

## Configuration Variables

Two variables control the image source registries:

- `OPERATOR_REGISTRY`: Registry for the CloudNativePG operator image (default: `ghcr.io/cloudnative-pg`)
- `POSTGRESQL_REGISTRY`: Registry for PostgreSQL images (default: `ghcr.io/cloudnative-pg`)

## Configuration Methods

### Method 1: Settings File (Recommended)

Edit [settings.yaml](../settings.yaml):

```yaml
# Image Registry Configuration
OPERATOR_REGISTRY: "my-registry.example.com/cloudnative-pg"
POSTGRESQL_REGISTRY: "my-registry.example.com/postgresql"
```

Then build normally:

```bash
make build
```

### Method 2: Environment Variables

```bash
export OPERATOR_REGISTRY=my-registry.example.com/cloudnative-pg
export POSTGRESQL_REGISTRY=my-registry.example.com/postgresql
make build
```

### Method 3: Makefile Variables

```bash
make build \
  OPERATOR_REGISTRY=my-registry.example.com/cloudnative-pg \
  POSTGRESQL_REGISTRY=my-registry.example.com/postgresql
```

### Method 4: Direct OCM CLI

```bash
ocm add componentversions \
  --create \
  --file ./build \
  ./component-constructor.yaml \
  OPERATOR_REGISTRY=my-registry.example.com/cloudnative-pg \
  POSTGRESQL_REGISTRY=my-registry.example.com/postgresql \
  CNPG_VERSION=1.24.1 \
  PG_VERSION_17=17 \
  PG_VERSION_16=16 \
  PG_VERSION_15=15 \
  PG_VERSION_14=14
```

## Expected Image Structure

Your private registry should contain images with the following structure:

### Operator Image

```
${OPERATOR_REGISTRY}/cloudnative-pg:${CNPG_VERSION}
```

Example: `my-registry.example.com/cloudnative-pg/cloudnative-pg:1.24.1`

### PostgreSQL Images

```
${POSTGRESQL_REGISTRY}/postgresql:${PG_VERSION_XX}
```

Examples:

- `my-registry.example.com/postgresql/postgresql:17`
- `my-registry.example.com/postgresql/postgresql:16`
- `my-registry.example.com/postgresql/postgresql:15`
- `my-registry.example.com/postgresql/postgresql:14`

## Mirroring Images

To mirror the official images to your private registry:

```bash
# Mirror operator image
docker pull ghcr.io/cloudnative-pg/cloudnative-pg:1.24.1
docker tag ghcr.io/cloudnative-pg/cloudnative-pg:1.24.1 \
  my-registry.example.com/cloudnative-pg/cloudnative-pg:1.24.1
docker push my-registry.example.com/cloudnative-pg/cloudnative-pg:1.24.1

# Mirror PostgreSQL images
for version in 17 16 15 14; do
  docker pull ghcr.io/cloudnative-pg/postgresql:${version}
  docker tag ghcr.io/cloudnative-pg/postgresql:${version} \
    my-registry.example.com/postgresql/postgresql:${version}
  docker push my-registry.example.com/postgresql/postgresql:${version}
done
```

## Verifying Configuration

After configuration, verify the registry settings:

```bash
make info
```

This will display the configured registries:

```
Image Registries:
  Operator:       my-registry.example.com/cloudnative-pg
  PostgreSQL:     my-registry.example.com/postgresql
```

To verify that all images are accessible:

```bash
make verify-images
```

## Mixed Registry Scenarios

You can use different registries for operator and PostgreSQL images:

```yaml
# Operator from public registry, PostgreSQL from private
OPERATOR_REGISTRY: "ghcr.io/cloudnative-pg"
POSTGRESQL_REGISTRY: "my-registry.example.com/postgresql"
```

Or vice versa:

```yaml
# Operator from private registry, PostgreSQL from public
OPERATOR_REGISTRY: "my-registry.example.com/cloudnative-pg"
POSTGRESQL_REGISTRY: "ghcr.io/cloudnative-pg"
```

## Troubleshooting

### Image Pull Errors

If you encounter image pull errors during deployment:

1. Verify the registry URL is correct
2. Ensure you have authentication configured for the registry
3. Check that the images exist at the expected paths
4. Verify the version tags match

### Authentication

For private registries requiring authentication, ensure your Kubernetes cluster has:

- Image pull secrets configured
- ServiceAccount with imagePullSecrets reference
- Or cluster-wide registry authentication

Example ImagePullSecret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

## Examples

### Example 1: Air-Gapped Environment

```yaml
OPERATOR_REGISTRY: "harbor.internal.company.com/cnpg"
POSTGRESQL_REGISTRY: "harbor.internal.company.com/cnpg"
```

### Example 2: Multi-Cloud Scenario

```yaml
OPERATOR_REGISTRY: "gcr.io/my-project/cloudnative-pg"
POSTGRESQL_REGISTRY: "gcr.io/my-project/postgresql"
```

### Example 3: Development Environment

```yaml
OPERATOR_REGISTRY: "localhost:5000/cloudnative-pg"
POSTGRESQL_REGISTRY: "localhost:5000/postgresql"
```
