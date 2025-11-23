# Air-Gapped Deployment Guide

This document explains how to deploy CloudNativePG in air-gapped environments using OCM component relocation.

## Overview

In air-gapped environments, you cannot pull container images directly from public registries. The OCM approach for air-gapped deployment involves:

1. **Build** the OCM component package (referencing upstream images)
2. **Transport** the component to your air-gapped OCM registry (OCM relocates the images)
3. **Configure** deployment manifests to reference the relocated images
4. **Deploy** using the relocated images

## Understanding OCM Image Relocation

When you transfer an OCM component to a new registry, OCM automatically:
- Copies all referenced container images to the target registry
- Updates image references in the component metadata
- Makes images available at predictable paths in the new registry

However, **deployment manifests** (Kubernetes YAML files) still need to be configured to pull from the relocated registry.

## Deployment Process

### Step 1: Build the Component (Outside Air-Gap)

Build the component normally, referencing upstream images:

```bash
# Build with default upstream registry references
make build

# Verify the component
make show
```

The component will reference images from `ghcr.io/cloudnative-pg/`.

### Step 2: Transport to Air-Gapped Registry

Transfer the component to your air-gapped OCM registry. OCM will automatically relocate all images:

```bash
# Transfer component and all images to air-gapped registry
ocm transfer componentversions ./build my-airgap-registry.company.com/ocm

# OCM will copy:
# - ghcr.io/cloudnative-pg/cloudnative-pg:1.24.1
#   → my-airgap-registry.company.com/ocm/cloudnative-pg:1.24.1
# - ghcr.io/cloudnative-pg/postgresql:17
#   → my-airgap-registry.company.com/ocm/postgresql:17
# (and all other PostgreSQL versions)
```

### Step 3: Extract Deployment Manifests

Extract the configuration templates from the relocated component:

```bash
# Get the component from air-gapped registry
ocm get componentversion my-airgap-registry.company.com/ocm//ocm.software/cloudnative-pg:1.24.1

# Download operator configuration template
ocm download resource my-airgap-registry.company.com/ocm//ocm.software/cloudnative-pg:1.24.1 \
  operator-configmap -O operator-configmap.yaml

# Download cluster template
ocm download resource my-airgap-registry.company.com/ocm//ocm.software/cloudnative-pg:1.24.1 \
  cluster-basic -O cluster.yaml
```

### Step 4: Configure for Relocated Images

The templates support environment variable substitution. Configure them to use your relocated images:

#### Operator Configuration

Edit or template the operator ConfigMap with relocated image references:

```bash
# Set environment variables for templating
export POSTGRES_IMAGE_NAME="my-airgap-registry.company.com/ocm/postgresql:16"
export OPERATOR_IMAGE_NAME="my-airgap-registry.company.com/ocm/cloudnative-pg:1.24.1"

# Apply with variable substitution
envsubst < operator-configmap.yaml | kubectl apply -f -
```

Or edit `operator-configmap.yaml` directly:

```yaml
data:
  # Configure default PostgreSQL image to use relocated registry
  POSTGRES_IMAGE_NAME: "my-airgap-registry.company.com/ocm/postgresql:16"

  # Configure operator image to use relocated registry
  OPERATOR_IMAGE_NAME: "my-airgap-registry.company.com/ocm/cloudnative-pg:1.24.1"
```

#### Cluster Configuration

Configure cluster manifests to use relocated images:

```bash
# Set the relocated image
export IMAGE_NAME="my-airgap-registry.company.com/ocm/postgresql:16"

# Apply with variable substitution
envsubst < cluster.yaml | kubectl apply -f -
```

Or edit the cluster YAML directly:

```yaml
spec:
  # Use relocated PostgreSQL image
  imageName: my-airgap-registry.company.com/ocm/postgresql:16
```

### Step 5: Deploy

Deploy the operator and clusters normally:

```bash
# Deploy operator with relocated configuration
kubectl apply -f operator-configmap.yaml
kubectl apply -f operator-deployment.yaml

# Deploy clusters
kubectl apply -f cluster.yaml
```

## Template Variables Reference

All cluster configuration templates support the `IMAGE_NAME` variable for specifying the PostgreSQL image:

```yaml
spec:
  # Default uses upstream registry
  imageName: ${IMAGE_NAME:-ghcr.io/cloudnative-pg/postgresql:${POSTGRES_VERSION:-16}}
```

This can be overridden at deployment time:

```bash
# Method 1: Environment variable substitution
export IMAGE_NAME="my-registry.company.com/ocm/postgresql:16"
envsubst < cluster-basic.yaml | kubectl apply -f -

# Method 2: Direct edit before applying
sed -i 's|${IMAGE_NAME:-ghcr.io/cloudnative-pg/postgresql:${POSTGRES_VERSION:-16}}|my-registry.company.com/ocm/postgresql:16|' cluster-basic.yaml
kubectl apply -f cluster-basic.yaml
```

## Complete Example

Here's a complete workflow for air-gapped deployment:

```bash
# ============================================
# Outside Air-Gap: Build and Transfer
# ============================================

# Build the component
make build

# Transfer to air-gapped registry (OCM relocates images automatically)
ocm transfer componentversions ./build \
  airgap-registry.internal.company.com/ocm

# ============================================
# Inside Air-Gap: Configure and Deploy
# ============================================

# Extract configuration templates
OCM_COMPONENT="airgap-registry.internal.company.com/ocm//ocm.software/cloudnative-pg:1.24.1"

ocm download resource $OCM_COMPONENT operator-configmap -O operator-config.yaml
ocm download resource $OCM_COMPONENT cluster-basic -O cluster.yaml

# Configure environment variables for relocated images
export POSTGRES_IMAGE_NAME="airgap-registry.internal.company.com/ocm/postgresql:16"
export OPERATOR_IMAGE_NAME="airgap-registry.internal.company.com/ocm/cloudnative-pg:1.24.1"
export IMAGE_NAME="airgap-registry.internal.company.com/ocm/postgresql:16"

# Apply operator configuration
envsubst < operator-config.yaml | kubectl apply -f -

# Deploy operator (download operator manifests from component separately)
# or use Helm chart if available

# Create a cluster
envsubst < cluster.yaml | kubectl apply -f -
```

## Determining Relocated Image Paths

OCM uses predictable paths when relocating images. The general pattern is:

```
<target-registry>/<repository-prefix>/<image-name>:<tag>
```

For example, if transferring to `my-registry.com/ocm`:
- Source: `ghcr.io/cloudnative-pg/postgresql:16`
- Target: `my-registry.com/ocm/postgresql:16`

You can inspect the relocated component to see exact paths:

```bash
# List all resources in the component
ocm get resources my-registry.com/ocm//ocm.software/cloudnative-pg:1.24.1

# Get detailed info about a specific image
ocm get resource my-registry.com/ocm//ocm.software/cloudnative-pg:1.24.1 \
  postgresql-16 -o yaml
```

## Using Helm Charts

If using Helm charts for deployment, override image values:

```bash
# Extract Helm chart from component (if available)
ocm download resource $OCM_COMPONENT helm-chart -O cnpg-chart.tgz

# Install with custom image values
helm install cloudnative-pg cnpg-chart.tgz \
  --set image.repository=airgap-registry.internal.company.com/ocm/cloudnative-pg \
  --set image.tag=1.24.1 \
  --set config.postgres.image.repository=airgap-registry.internal.company.com/ocm/postgresql \
  --set config.postgres.image.tag=16
```

## Registry Authentication

Ensure your Kubernetes cluster has access to the air-gapped registry:

### Option 1: Cluster-wide Registry Configuration

Configure containerd or CRI-O with registry credentials.

### Option 2: Image Pull Secrets

Create and use ImagePullSecrets:

```bash
# Create registry credentials secret
kubectl create secret docker-registry airgap-registry-creds \
  --docker-server=airgap-registry.internal.company.com \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>

# Reference in operator ServiceAccount
kubectl patch serviceaccount cnpg-operator \
  -p '{"imagePullSecrets": [{"name": "airgap-registry-creds"}]}'

# For clusters, add to the Cluster spec
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-cluster
spec:
  imageName: airgap-registry.internal.company.com/ocm/postgresql:16
  imagePullSecrets:
    - name: airgap-registry-creds
```

### Option 3: Operator ConfigMap

Configure pull secret name in operator configuration:

```yaml
data:
  PULL_SECRET_NAME: "airgap-registry-creds"
```

## Troubleshooting

### Image Pull Errors

If you see `ImagePullBackOff` errors:

1. Verify image exists in relocated registry:
   ```bash
   crane manifest airgap-registry.internal.company.com/ocm/postgresql:16
   ```

2. Check authentication:
   ```bash
   kubectl get secret airgap-registry-creds -o yaml
   ```

3. Verify image reference in pod spec:
   ```bash
   kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'
   ```

### Wrong Registry Referenced

If pods still try to pull from `ghcr.io`:

1. Check operator configuration:
   ```bash
   kubectl get configmap cnpg-controller-manager-config -o yaml
   ```

2. Verify `POSTGRES_IMAGE_NAME` and `OPERATOR_IMAGE_NAME` are set correctly

3. For existing clusters, update the Cluster spec:
   ```bash
   kubectl patch cluster my-cluster --type merge -p '{"spec":{"imageName":"airgap-registry.internal.company.com/ocm/postgresql:16"}}'
   ```

## Best Practices

1. **Version Pinning**: Always use specific version tags, not `latest`
2. **Pre-validation**: Test image accessibility before deploying clusters
3. **Documentation**: Document your relocated image paths for your team
4. **Automation**: Script the template substitution process
5. **Monitoring**: Monitor image pull metrics to catch authentication issues early

## Reference: All Configuration Templates

All templates support image customization:

- `cluster-basic`: Basic development cluster → `IMAGE_NAME`
- `cluster-ha`: High-availability cluster → `IMAGE_NAME`
- `cluster-backup-s3`: Cluster with S3 backup → `IMAGE_NAME`
- `cluster-backup-gcs`: Cluster with GCS backup → `IMAGE_NAME`
- `cluster-backup-azure`: Cluster with Azure backup → `IMAGE_NAME`
- `cluster-monitoring`: Cluster with monitoring → `IMAGE_NAME`
- `operator-configmap`: Operator configuration → `POSTGRES_IMAGE_NAME`, `OPERATOR_IMAGE_NAME`
