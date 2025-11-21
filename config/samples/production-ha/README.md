# Production High Availability Cluster

This configuration provides a production-ready PostgreSQL cluster with high availability, backups, and monitoring.

## Features

- **High Availability**: 3 instances (1 primary + 2 replicas)
- **Synchronous Replication**: 1-2 sync replicas for data safety
- **Automated Backups**: Daily backups to S3 with 30-day retention
- **WAL Archiving**: Continuous archiving to S3
- **Monitoring**: Prometheus PodMonitor with custom queries
- **Resource Limits**: Production-sized resources (2-4 CPU, 4-8Gi RAM)
- **Pod Anti-Affinity**: Instances on different nodes
- **Managed Roles**: Read-only user for reporting

## Prerequisites

1. **Kubernetes Cluster** with at least 3 nodes
2. **StorageClass** named `fast-ssd` (or update the configuration)
3. **S3 Bucket** for backups
4. **Prometheus Operator** for monitoring
5. **Namespace** named `production`

## Configuration Steps

### 1. Create Namespace

```bash
kubectl create namespace production
```

### 2. Update Secrets

Edit the secrets in `cluster.yaml` and replace:
- `YOUR_ACCESS_KEY` and `YOUR_SECRET_KEY` with actual S3 credentials
- `CHANGE_ME_STRONG_PASSWORD` with a strong password (use a password generator)
- `CHANGE_ME_READONLY_PASSWORD` with a strong readonly password

### 3. Update S3 Path

Replace `s3://my-backup-bucket/postgresql/production` with your actual S3 bucket path.

### 4. Apply Configuration

```bash
kubectl apply -f cluster.yaml
```

### 5. Verify Deployment

```bash
# Check cluster status
kubectl get cluster -n production

# Check pods
kubectl get pods -n production

# Check backup status
kubectl get backup -n production
```

## Connecting to the Database

### Primary (Read-Write)

```bash
# Get password
kubectl get secret pg-production-app-user -n production -o jsonpath='{.data.password}' | base64 -d

# Service name: pg-production-rw.production.svc.cluster.local
# Port: 5432
# Username: myapp
# Database: myapp
```

### Replicas (Read-Only)

```bash
# Service name: pg-production-ro.production.svc.cluster.local
# Or use readonly user with pg-production-rw for read-only queries
```

## Backup and Recovery

### Manual Backup

```bash
kubectl cnpg backup pg-production -n production
```

### List Backups

```bash
kubectl get backup -n production
```

### Point-in-Time Recovery

Create a new cluster from backup:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-restored
spec:
  bootstrap:
    recovery:
      source: pg-production
  externalClusters:
    - name: pg-production
      barmanObjectStore:
        destinationPath: s3://my-backup-bucket/postgresql/production
        s3Credentials:
          # ... same as original cluster
```

## Monitoring

Access metrics:

```bash
# Port-forward to metrics endpoint
kubectl port-forward -n production svc/pg-production-rw 9187:9187

# Access metrics
curl http://localhost:9187/metrics
```

Grafana dashboards are available at:
https://github.com/cloudnative-pg/grafana-dashboards

## Maintenance

### Trigger Switchover

```bash
kubectl cnpg promote pg-production-2 -n production
```

### Scale Cluster

```bash
kubectl cnpg scale pg-production --instances 5 -n production
```

### Upgrade PostgreSQL

Update the `imageName` in the cluster spec and apply:

```bash
kubectl apply -f cluster.yaml
```

## Troubleshooting

### Check Cluster Status

```bash
kubectl cnpg status pg-production -n production
```

### View Logs

```bash
kubectl logs -n production pg-production-1 -c postgres
```

### Check Replication

```bash
kubectl exec -n production pg-production-1 -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

## Security Recommendations

1. **Rotate Passwords Regularly**: Update secrets and restart pods
2. **Use Network Policies**: Restrict database access
3. **Enable TLS**: Configure SSL certificates
4. **Audit Logging**: Enable PostgreSQL audit extension
5. **Backup Encryption**: Ensure S3 bucket has encryption enabled
