# PostgreSQL Extensions Support

This directory contains documentation and examples for using PostgreSQL extensions with CloudNativePG.

## Overview

CloudNativePG supports PostgreSQL extensions through several mechanisms:

1. **Pre-installed extensions**: Extensions included in the PostgreSQL image
2. **Custom PostgreSQL images**: Build images with additional extensions
3. **Runtime installation**: Install extensions via initdb or postInitSQL

## Common Extensions

The official CloudNativePG PostgreSQL images include these commonly-used extensions:

### Included in Base Image
- `pg_stat_statements` - Query execution statistics
- `pgcrypto` - Cryptographic functions
- `pg_trgm` - Trigram matching for text search
- `btree_gin`, `btree_gist` - B-tree indexing for GIN and GiST
- `pg_buffercache` - Shared buffer cache inspection
- `pgrowlocks` - Row-level lock information
- `pg_prewarm` - Preload data into buffer cache
- `pgstattuple` - Tuple-level statistics

### PostGIS Support
For geospatial applications, use PostGIS-enabled images:
- `ghcr.io/cloudnative-pg/postgis` - PostgreSQL with PostGIS extension

## Using Extensions

### Method 1: Enable Pre-installed Extensions

Use `postInitSQL` or `postInitApplicationSQL` in your cluster configuration:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-cluster
spec:
  instances: 3
  bootstrap:
    initdb:
      database: app
      owner: app
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
        - CREATE EXTENSION IF NOT EXISTS pgcrypto;
      postInitApplicationSQL:
        - CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

### Method 2: Custom PostgreSQL Images

Build custom images with additional extensions:

```dockerfile
FROM ghcr.io/cloudnative-pg/postgresql:16

# Install additional extensions (example with timescaledb)
RUN apt-get update && \
    apt-get install -y postgresql-16-timescaledb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Make extension available
RUN echo "shared_preload_libraries = 'timescaledb'" >> /usr/share/postgresql/postgresql.conf.sample
```

Then reference your custom image:

```yaml
spec:
  imageName: my-registry.com/postgresql-timescaledb:16
  bootstrap:
    initdb:
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS timescaledb;
```

### Method 3: Runtime Installation via Init Containers

For extensions that don't require PostgreSQL restart:

```yaml
spec:
  initContainers:
    - name: install-extension
      image: my-extension-installer:latest
      command: ["/bin/sh", "-c"]
      args:
        - |
          # Install extension files
          cp /extensions/* /pgdata/extensions/
      volumeMounts:
        - name: pgdata
          mountPath: /pgdata
```

## Extension Component References

The OCM component can reference extension packages as component dependencies:

```yaml
# In component-constructor.yaml
componentReferences:
  - name: postgis-extension
    componentName: ocm.software/postgresql-postgis
    version: "3.4.0"
    labels:
      - name: "cnpg.io/extension-type"
        value: "geospatial"

  - name: timescaledb-extension
    componentName: ocm.software/postgresql-timescaledb
    version: "2.13.0"
    labels:
      - name: "cnpg.io/extension-type"
        value: "timeseries"

  - name: pgvector-extension
    componentName: ocm.software/postgresql-pgvector
    version: "0.5.1"
    labels:
      - name: "cnpg.io/extension-type"
        value: "vector-search"
```

## Popular Extensions by Use Case

### Time Series Data
- **TimescaleDB**: Time-series database built on PostgreSQL
  - Requires: custom image or package installation
  - Image: `timescale/timescaledb:latest-pg16`

### Vector/Embeddings Search
- **pgvector**: Vector similarity search for AI/ML workloads
  - Requires: custom image
  - Use case: Semantic search, embeddings storage

### Geospatial
- **PostGIS**: Spatial and geographic objects
  - Official image: `ghcr.io/cloudnative-pg/postgis:16`
  - Extensions: `postgis`, `postgis_topology`, `postgis_raster`

### Full-Text Search
- **pg_trgm**: Trigram matching (included in base image)
- **pg_search**: Advanced full-text search
- **RUM**: Advanced GIN index for full-text search

### Data Types
- **hstore**: Key-value store (included)
- **ltree**: Hierarchical tree-like structures (included)
- **citext**: Case-insensitive text (included)
- **uuid-ossp**: UUID generation (included)

### Performance & Monitoring
- **pg_stat_statements**: Query statistics (included)
- **pg_hint_plan**: Query execution hints
- **auto_explain**: Automatic EXPLAIN logging

### Foreign Data Wrappers (FDW)
- **postgres_fdw**: Connect to other PostgreSQL databases (included)
- **file_fdw**: Read data from files (included)
- **mysql_fdw**: Connect to MySQL
- **mongo_fdw**: Connect to MongoDB

### Security
- **pgcrypto**: Cryptographic functions (included)
- **pg_cron**: Job scheduler
- **pgaudit**: Audit logging

## Building Custom Images with Extensions

Example Makefile for building custom PostgreSQL images:

```makefile
PG_VERSION ?= 16
REGISTRY ?= my-registry.com
IMAGE_NAME ?= postgresql-custom

.PHONY: build-timescaledb
build-timescaledb:
	docker build -t $(REGISTRY)/$(IMAGE_NAME)-timescaledb:$(PG_VERSION) \
		--build-arg PG_VERSION=$(PG_VERSION) \
		-f Dockerfile.timescaledb .
	docker push $(REGISTRY)/$(IMAGE_NAME)-timescaledb:$(PG_VERSION)

.PHONY: build-postgis
build-postgis:
	docker build -t $(REGISTRY)/$(IMAGE_NAME)-postgis:$(PG_VERSION) \
		--build-arg PG_VERSION=$(PG_VERSION) \
		-f Dockerfile.postgis .
	docker push $(REGISTRY)/$(IMAGE_NAME)-postgis:$(PG_VERSION)
```

## Best Practices

1. **Use official images when available**: CloudNativePG provides PostGIS images
2. **Minimize image size**: Only include necessary extensions
3. **Version pin extensions**: Ensure consistency across deployments
4. **Test thoroughly**: Verify extensions work with your PostgreSQL version
5. **Document dependencies**: Maintain clear documentation of required extensions
6. **Security scanning**: Scan custom images for vulnerabilities

## Troubleshooting

### Extension Not Found

```sql
ERROR:  extension "extension_name" is not available
```

**Solution**: Install the extension package or use a custom image.

### Shared Library Issues

```
ERROR: could not load library "/usr/lib/postgresql/16/lib/extension.so"
```

**Solution**: Ensure the extension is compatible with your PostgreSQL version and restart the cluster if shared_preload_libraries was modified.

### Permission Denied

```
ERROR:  permission denied to create extension "extension_name"
```

**Solution**: Connect as superuser or ensure the extension is in the allowed list.

## References

- [PostgreSQL Extensions Documentation](https://www.postgresql.org/docs/current/external-extensions.html)
- [CloudNativePG Custom Images](https://cloudnative-pg.io/documentation/current/container_images/)
- [PostgreSQL Extension Network (PGXN)](https://pgxn.org/)
