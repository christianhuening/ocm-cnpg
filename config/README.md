# Configuration Templates

This directory contains configuration templates for deploying CloudNativePG operator and clusters.

## Structure

- **operator/** - Operator-level configuration templates
- **cluster/** - Cluster-level configuration templates
- **samples/** - Complete example configurations

## Status

🚧 **Phase 3: Configuration Management** - Not yet implemented

## Planned Templates

### Operator Configuration (`operator/`)

Templates for operator environment variables and ConfigMap:

- `operator-config.yaml` - Base operator configuration
- `monitoring-queries.yaml` - Custom monitoring queries
- `rbac.yaml` - RBAC resources for operator

### Cluster Configuration (`cluster/`)

Parameterized templates for PostgreSQL cluster deployments:

- `basic-cluster.yaml` - Minimal viable cluster
- `ha-cluster.yaml` - High-availability cluster with replicas
- `backup-s3.yaml` - Cluster with S3 backup configuration
- `backup-gcs.yaml` - Cluster with GCS backup configuration
- `backup-azure.yaml` - Cluster with Azure backup configuration
- `monitoring.yaml` - Cluster with monitoring enabled
- `custom-postgres.yaml` - Cluster with custom PostgreSQL configuration

### Sample Configurations (`samples/`)

Complete, ready-to-deploy examples:

- `minimal/` - Minimal cluster for development
- `production-ha/` - Production HA setup with backups and monitoring
- `development/` - Development cluster with minimal resources
- `multi-region/` - Multi-region deployment with replica clusters

## Usage (Future)

Once implemented, templates will support variable substitution:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
spec:
  instances: ${INSTANCES}
  storage:
    size: ${STORAGE_SIZE}
```

Variables can be provided via:
1. Environment variables
2. Settings file
3. Command-line arguments

## See Also

- [CLAUDE.md](../CLAUDE.md) - Full implementation plan
- [docs/implementation-status.md](../docs/implementation-status.md) - Current progress
- [CloudNativePG API Reference](https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/)
