# CloudNativePG OCM Package

An [Open Component Model](https://ocm.software) package for [CloudNativePG](https://cloudnative-pg.io/), the comprehensive Kubernetes operator for PostgreSQL.

## Overview

This repository provides an OCM component that packages CloudNativePG with:

- CloudNativePG operator image (multi-architecture)
- PostgreSQL container images (versions 14, 15, 16, 17)
- Configuration templates for operator and cluster deployments
- Extensive configuration options for production deployments

## Prerequisites

- [OCM CLI](https://ocm.software/docs/cli-reference/download/cli/) installed
- Access to ghcr.io (GitHub Container Registry) to pull CloudNativePG images
- (Optional) Access to an OCM repository for publishing components

## Quick Start

### 1. Build the Component

```bash
# View available make targets
make help

# Build the OCM component archive with default settings
make build

# Or customize versions via settings.yaml
make build
```

### 2. View the Component

```bash
# Display the component descriptor
make show

# Validate the component
make validate
```

### 3. Push to Repository (Optional)

```bash
# Push to your OCM repository
OCM_REPO=ghcr.io/your-org/ocm make push
```

## Configuration

### Version Configuration

Edit [settings.yaml](settings.yaml) to customize versions:

```yaml
CNPG_VERSION: "1.24.1"
PG_VERSION_17: "17.2"
PG_VERSION_16: "16.6"
PG_VERSION_15: "15.10"
PG_VERSION_14: "14.15"
```

Or override via environment variables:

```bash
CNPG_VERSION=1.24.0 make build
```

### Component Configuration

Edit [component-constructor.yaml](component-constructor.yaml) to:

- Add additional PostgreSQL versions
- Include custom PostgreSQL images
- Add operator manifests or Helm charts
- Modify component labels and metadata

## Project Structure

```
ocm-cnpg/
├── component-constructor.yaml    # OCM component descriptor
├── settings.yaml                 # Version and configuration variables
├── Makefile                      # Build automation
├── config/                       # Configuration templates (future)
│   ├── operator/                 # Operator configuration templates
│   ├── cluster/                  # Cluster configuration templates
│   └── samples/                  # Example configurations
├── resources/                    # Local resources
└── docs/                         # Documentation
```

## Component Resources

The OCM component includes the following resources:

| Resource Name | Type | Description |
|---------------|------|-------------|
| `cloudnative-pg-operator` | ociImage | CloudNativePG operator (multi-arch) |
| `postgresql-17` | ociImage | PostgreSQL 17.x container image |
| `postgresql-16` | ociImage | PostgreSQL 16.x container image (default) |
| `postgresql-15` | ociImage | PostgreSQL 15.x container image |
| `postgresql-14` | ociImage | PostgreSQL 14.x container image |

All images support multiple architectures: linux/amd64, linux/arm64, linux/ppc64le, linux/s390x

## Usage

### Deploying with OCM

```bash
# Pull the component from a repository
ocm get component ocm.software/cloudnative-pg:1.24.1 -o yaml

# Download resources
ocm download resources <component-reference>

# Use with OCM localization and deployment tools
```

### Manual Deployment

The component references CloudNativePG images from ghcr.io. You can:

1. Use the images directly from the component descriptor
2. Transfer images to your private registry using OCM
3. Deploy using the official CloudNativePG manifests

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development information including:

- Complete implementation plan (phases 1-7)
- Configuration options reference
- OCM component descriptor format
- Build system details

## Make Targets

```bash
make help              # Show all available targets
make build             # Build OCM component archive
make validate          # Validate component descriptor
make show              # Display component descriptor
make push              # Push to OCM repository
make fetch-resources   # Download upstream manifests
make clean             # Clean build artifacts
make info              # Show build configuration
make all               # Clean, build, and validate
```

## License

Apache License 2.0 - See [LICENSE](LICENSE)

## Related Projects

- [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg) - PostgreSQL operator for Kubernetes
- [Open Component Model](https://ocm.software) - Standard for software bill of delivery
- [OCM CLI](https://github.com/open-component-model/ocm) - OCM command-line tools
