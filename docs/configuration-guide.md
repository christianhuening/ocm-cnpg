# CloudNativePG Configuration Guide

This guide explains how to use the configuration templates included in the OCM component.

## Overview

The CloudNativePG OCM package includes comprehensive configuration templates for:

1. **Operator Configuration** - Control operator behavior
2. **Cluster Templates** - Deploy PostgreSQL clusters with various profiles
3. **Sample Configurations** - Ready-to-use examples

## Template Types

### Operator Configuration Templates

Located in `config/operator/`:

#### operator-configmap.yaml

Configures the CloudNativePG operator with environment variables:

- Certificate management (duration, expiration threshold)
- Upgrade control (rollout delays)
- Default images (PostgreSQL, operator)
- Service configuration
- Monitoring queries
- Resource inheritance
- Plugin management

**Usage:**

```bash
# Download the template from OCM component
ocm download resource <component> operator-configmap -O operator-configmap.yaml

# Customize variables
export OPERATOR_NAMESPACE=cnpg-system
export CERTIFICATE_DURATION=90

# Apply to cluster
kubectl apply -f operator-configmap.yaml
```

#### monitoring-queries.yaml

Default monitoring queries for Prometheus metrics:

- Database size metrics
- Table bloat estimation
- Connection statistics
- Replication lag
- Transaction statistics
- Lock statistics

### Cluster Configuration Templates

Located in `config/cluster/`:

#### basic-cluster.yaml

Minimal PostgreSQL cluster for development:

- Single instance or configurable replicas
- Basic storage configuration
- Standard PostgreSQL parameters
- Application user setup

**Variables:**

```bash
CLUSTER_NAME=my-cluster
INSTANCES=1
STORAGE_SIZE=10Gi
POSTGRES_VERSION=16
CPU_REQUEST=500m
MEMORY_REQUEST=1Gi
```

#### ha-cluster.yaml

High availability production cluster:

- 3 instances (1 primary + 2 replicas)
- Synchronous replication (min 1, max 2 sync replicas)
- Pod anti-affinity for node distribution
- Production-sized resources
- Advanced PostgreSQL tuning
- Read-only user role

**Variables:**

```bash
CLUSTER_NAME=pg-ha-cluster
INSTANCES=3
MIN_SYNC_REPLICAS=1
STORAGE_SIZE=50Gi
STORAGE_CLASS=fast-ssd
CPU_REQUEST=2000m
MEMORY_REQUEST=4Gi
```

#### backup-s3.yaml

Cluster with S3 backup configuration:

- Automated backups to S3-compatible storage
- WAL archiving with compression and encryption
- Scheduled backups
- Point-in-time recovery support

**Variables:**

```bash
CLUSTER_NAME=pg-backup-cluster
BACKUP_S3_BUCKET=my-backup-bucket
BACKUP_S3_PATH=/pg-backups
BACKUP_S3_REGION=us-east-1
BACKUP_RETENTION_POLICY=30d
WAL_COMPRESSION=gzip
WAL_ENCRYPTION=AES256
```

**Required Secret:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: s3-backup-credentials
stringData:
  ACCESS_KEY_ID: "your-access-key"
  ACCESS_SECRET_KEY: "your-secret-key"
  REGION: "us-east-1"
```

#### backup-gcs.yaml

Cluster with Google Cloud Storage backup:

- Backups to GCS
- Service account authentication
- WAL archiving and compression

**Variables:**

```bash
CLUSTER_NAME=pg-gcs-cluster
BACKUP_GCS_BUCKET=my-gcs-bucket
BACKUP_GCS_PATH=/pg-backups
```

**Required Secret:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gcs-backup-credentials
stringData:
  APPLICATION_CREDENTIALS: |
    {
      "type": "service_account",
      "project_id": "your-project",
      ...
    }
```

#### backup-azure.yaml

Cluster with Azure Blob Storage backup:

- Backups to Azure Blob Storage
- Storage account or SAS token authentication

**Variables:**

```bash
CLUSTER_NAME=pg-azure-cluster
BACKUP_AZURE_ACCOUNT=mystorageaccount
BACKUP_AZURE_CONTAINER=pg-backups
```

#### monitoring.yaml

Cluster with full monitoring configuration:

- Prometheus PodMonitor enabled
- Custom monitoring queries
- PostgreSQL statistics extensions
- Detailed logging
- Performance tracking

**Variables:**

```bash
CLUSTER_NAME=pg-monitoring-cluster
ENABLE_POD_MONITOR=true
CUSTOM_QUERIES_CONFIGMAP=cnpg-monitoring-queries
```

## Sample Configurations

### Minimal Development Cluster

Located in `config/samples/minimal/`:

```bash
# Download sample
ocm download resource <component> cluster-basic -O cluster.yaml

# Or use the minimal sample
kubectl apply -f config/samples/minimal/cluster.yaml
```

Features:
- 1 instance
- 5Gi storage
- Minimal resources (100m CPU, 256Mi RAM)
- No backups
- Simple authentication

### Production HA Cluster

Located in `config/samples/production-ha/`:

```bash
kubectl apply -f config/samples/production-ha/cluster.yaml
```

Features:
- 3 instances with synchronous replication
- S3 backups with 30-day retention
- Prometheus monitoring
- Production resources (2-4 CPU, 4-8Gi RAM)
- Read-only user
- Daily scheduled backups

## Variable Substitution

All templates support variable substitution using `${VARIABLE_NAME:-default}` syntax.

### Methods to Provide Variables

1. **Environment Variables:**

```bash
export CLUSTER_NAME=my-cluster
export INSTANCES=3
kubectl apply -f cluster.yaml
```

2. **envsubst Command:**

```bash
CLUSTER_NAME=my-cluster INSTANCES=3 envsubst < cluster.yaml | kubectl apply -f -
```

3. **Helm or Kustomize:**

Use Helm values or Kustomize patches to substitute variables.

## Common Configuration Patterns

### Development Environment

```yaml
INSTANCES=1
STORAGE_SIZE=5Gi
CPU_REQUEST=100m
MEMORY_REQUEST=256Mi
BACKUP_ENABLED=false
```

### Staging Environment

```yaml
INSTANCES=2
STORAGE_SIZE=20Gi
CPU_REQUEST=500m
MEMORY_REQUEST=1Gi
BACKUP_ENABLED=true
BACKUP_RETENTION_POLICY=7d
```

### Production Environment

```yaml
INSTANCES=3
MIN_SYNC_REPLICAS=1
STORAGE_SIZE=100Gi
STORAGE_CLASS=fast-ssd
CPU_REQUEST=2000m
MEMORY_REQUEST=4Gi
BACKUP_ENABLED=true
BACKUP_RETENTION_POLICY=30d
ENABLE_MONITORING=true
```

## Best Practices

### Security

1. **Strong Passwords:** Use password generators for database credentials
2. **Secret Management:** Store credentials in Kubernetes Secrets
3. **Network Policies:** Restrict database access
4. **TLS:** Enable SSL certificates for connections
5. **Backup Encryption:** Enable encryption for backups

### High Availability

1. **Multi-Node:** Deploy across multiple Kubernetes nodes
2. **Sync Replication:** Configure at least 1 synchronous replica
3. **Anti-Affinity:** Use pod anti-affinity for node distribution
4. **Monitoring:** Enable PodMonitor for observability
5. **Backups:** Schedule regular backups with adequate retention

### Performance

1. **Resource Sizing:** Right-size CPU and memory based on workload
2. **Storage Class:** Use fast SSDs for production
3. **WAL Storage:** Separate WAL to different storage for I/O
4. **Connection Pooling:** Configure appropriate max_connections
5. **PostgreSQL Tuning:** Adjust shared_buffers, work_mem, etc.

### Backup Strategy

1. **Regular Backups:** Daily scheduled backups minimum
2. **Retention Policy:** At least 30 days for production
3. **Test Restores:** Regularly test backup recovery
4. **WAL Archiving:** Enable continuous archiving
5. **Multiple Regions:** Consider cross-region backup replication

## Troubleshooting

### Template Variable Issues

If variables aren't substituted:

```bash
# Check if using correct syntax
grep -r '\${' config/

# Verify environment variables are set
env | grep CLUSTER

# Use envsubst for manual substitution
envsubst < template.yaml
```

### Configuration Errors

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f cluster.yaml

# Check CloudNativePG API
kubectl explain cluster.spec

# View operator logs
kubectl logs -n cnpg-system deploy/cnpg-controller-manager
```

## Reference

- [CloudNativePG API Reference](https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/)
- [CloudNativePG Configuration](https://cloudnative-pg.io/documentation/current/operator_conf/)
- [Backup Documentation](https://cloudnative-pg.io/documentation/current/backup/)
- [Monitoring Documentation](https://cloudnative-pg.io/documentation/current/monitoring/)
