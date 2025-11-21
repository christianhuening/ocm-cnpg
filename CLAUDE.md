# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository packages CloudNativePG as an OCM (Open Component Model) component, including the operator, all required container images, and extensive configuration options for controlling operator behavior and database clusters.

**Project Context:**
- OCM (Open Component Model) is a standard for describing software artifacts and their dependencies
- CloudNativePG is a comprehensive Kubernetes operator for managing PostgreSQL databases
- This package includes operator images, PostgreSQL images (multiple versions), and configuration templates

## Project Structure

```
ocm-cnpg/
├── component-constructor.yaml    # Main OCM component descriptor
├── settings.yaml                 # Variable values for templating
├── Makefile                      # Build automation
├── config/
│   ├── operator/                 # Operator configuration templates
│   ├── cluster/                  # Cluster configuration templates
│   └── samples/                  # Example configurations
├── resources/                    # Local resources to include
└── docs/                         # Usage documentation
```

## Common Commands

```bash
# Build the OCM component archive
make build

# Validate the component descriptor
make validate

# Push to OCM repository
make push

# Fetch upstream CloudNativePG resources
make fetch-resources

# Clean build artifacts
make clean
```

## Component Architecture

### OCM Resources

The component includes these resources:

1. **Operator Image**: CloudNativePG operator container image
2. **PostgreSQL Images**: Multiple PostgreSQL versions (14, 15, 16, 17)
3. **Operator Manifests**: Kubernetes manifests for operator deployment
4. **Configuration Schema**: JSON Schema for validating configurations
5. **Helm Charts**: Optional Helm chart packaging

### Configuration Layers

Configuration is managed in three layers:

1. **Base Configuration**: Minimal viable settings in `component-constructor.yaml`
2. **Settings File**: User-provided values in `settings.yaml`
3. **Templates**: Parameterized cluster/operator configs in `config/`

## Implementation Plan

### Phase 1: Project Structure & Tooling Setup

**1.1 Repository Structure**
- Create directory structure for config/, resources/, docs/
- Set up proper .gitignore for build artifacts

**1.2 Tooling Requirements**
- OCM CLI (`ocm`) - Install from https://ocm.software/docs/cli-reference/download/cli/
- Container registry access (ghcr.io for CloudNativePG images)

### Phase 2: Component Descriptor Design

**2.1 Required Images**
- Operator: `ghcr.io/cloudnative-pg/cloudnative-pg:<version>`
- PostgreSQL: Multiple versions from `ghcr.io/cloudnative-pg/postgresql`

**2.2 Component Descriptor**
- Create templated `component-constructor.yaml`
- Define resources with proper access types (ociArtifact)
- Add labels for metadata and versioning

### Phase 3: Configuration Management

**3.1 Operator-Level Configuration**
- Template for operator environment variables
- Certificate management settings
- Rollout control parameters
- Default image settings
- Monitoring and inheritance options

**3.2 Cluster-Level Configuration**
- Basic cluster templates (instances, storage, resources)
- Backup configuration (BarmanObjectStore, VolumeSnapshot)
- Monitoring and PostgreSQL parameters
- HA and replication settings

**3.3 Configuration Composition**
- Base configurations for common scenarios
- Overlay system for production/dev/HA profiles

### Phase 4: Build System

**4.1 Makefile Targets**
- `fetch-resources`: Download upstream manifests and charts
- `validate`: Validate component descriptor
- `build`: Create OCM component archive using `ocm add componentversions`
- `push`: Transfer to OCM repository
- `docs`: Generate documentation from schema

**4.2 Version Management**
- Version matrix file for operator and PostgreSQL versions
- Automated image reference resolution

### Phase 5: Advanced Features

- Multi-architecture image support
- Configuration validation JSON Schema
- Component references for extensions
- Custom PostgreSQL image support

### Phase 6: Testing & Documentation

- Integration tests for component structure
- Configuration reference documentation
- Example configurations (minimal, HA, backup-enabled)
- Deployment and migration guides

### Phase 7: CI/CD Integration

- GitHub Actions for automated builds
- Automated version updates
- Publishing pipeline

## Key Configuration Options

### Operator-Level Settings (Environment Variables)

- `CERTIFICATE_DURATION`: Certificate lifetime (default: 90 days)
- `CLUSTERS_ROLLOUT_DELAY`: Seconds between cluster upgrades
- `INSTANCES_ROLLOUT_DELAY`: Seconds between instance upgrades
- `POSTGRES_IMAGE_NAME`: Default PostgreSQL image
- `OPERATOR_IMAGE_NAME`: Operator image for bootstrapping
- `CREATE_ANY_SERVICE`: Enable `-any` service creation
- `ENABLE_INSTANCE_MANAGER_INPLACE_UPDATES`: Skip rolling updates
- `MONITORING_QUERIES_CONFIGMAP/SECRET`: Default monitoring queries
- `INHERITED_ANNOTATIONS/LABELS`: Propagated to managed resources

### Cluster-Level Settings (Cluster Spec)

**Core Settings:**
- `instances`: Number of PostgreSQL instances
- `storage.size`: Storage size per instance
- `storage.storageClass`: Kubernetes StorageClass
- `postgresql.parameters`: PostgreSQL configuration parameters
- `resources`: CPU and memory requests/limits

**Backup Settings:**
- `backup.barmanObjectStore.destinationPath`: S3/GCS/Azure destination
- `backup.barmanObjectStore.retentionPolicy`: Backup retention period
- `backup.barmanObjectStore.wal.compression`: WAL compression (gzip, bzip2, snappy)
- `backup.volumeSnapshot.className`: VolumeSnapshot class

**Monitoring:**
- `monitoring.enablePodMonitor`: Enable Prometheus PodMonitor
- Custom SQL queries for metrics

## Development Notes

### OCM Component Descriptor Format

- Uses component-constructor.yaml as the descriptor
- Supports templating with `${VARIABLE}` syntax
- Variables provided via settings.yaml or command-line
- Resources can be local (input) or remote (access)

### CloudNativePG Architecture

- Operator injects itself into each PostgreSQL pod
- Instance manager runs inside pods to manage PostgreSQL
- No external dependencies like Patroni or Stolon
- Multi-architecture support (amd64, arm64, ppc64le, s390x)

### Building OCM Components

```bash
# Create component archive with templating
ocm add componentversions \
    --create \
    --file ./build \
    ./component-constructor.yaml \
    CNPG_VERSION=1.27.0 \
    PG16_VERSION=16.8

# Examine component
ocm get componentversions ./build -o yaml

# Transfer to registry
ocm transfer componentversions ./build ghcr.io/your-org/ocm
```

### Configuration Templating

Variables are resolved in this order:
1. Environment variables
2. Settings file (settings.yaml)
3. Command-line arguments

This allows flexible override mechanisms for different deployment scenarios.
