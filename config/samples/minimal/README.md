# Minimal Development Cluster

This configuration provides a minimal PostgreSQL cluster for development and testing.

## Features

- Single PostgreSQL instance
- Minimal resource allocation (100m CPU, 256Mi RAM)
- 5Gi storage
- No backups
- No monitoring
- Simple authentication

## Usage

```bash
kubectl apply -f cluster.yaml
```

## Connecting

Get the connection details:

```bash
# Get the password
kubectl get secret pg-dev-app-user -o jsonpath='{.data.password}' | base64 -d

# Port-forward to connect
kubectl port-forward svc/pg-dev-rw 5432:5432

# Connect via psql
psql -h localhost -U app -d app
```

## Warnings

⚠️ This configuration is for **development only**:
- No high availability
- No backups
- Minimal resources
- Weak password security
