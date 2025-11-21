# Getting Started with CloudNativePG OCM Package

This guide walks you through building and using the CloudNativePG OCM component.

## Prerequisites

### Install OCM CLI

Follow the installation instructions at [https://ocm.software/docs/cli-reference/download/cli/](https://ocm.software/docs/cli-reference/download/cli/)

For macOS:
```bash
brew install open-component-model/tap/ocm
```

For Linux:
```bash
curl -LO https://github.com/open-component-model/ocm/releases/latest/download/ocm-linux-amd64
chmod +x ocm-linux-amd64
sudo mv ocm-linux-amd64 /usr/local/bin/ocm
```

Verify installation:
```bash
ocm version
```

## Building the Component

### Step 1: Review Configuration

Check the default configuration:
```bash
make info
```

### Step 2: Customize Versions (Optional)

Edit `settings.yaml` to set specific versions:
```yaml
CNPG_VERSION: "1.24.1"
PG_VERSION_16: "16.6"
```

### Step 3: Build the Component Archive

```bash
make build
```

This will:
1. Create a `build/` directory
2. Generate the OCM component archive (CTF format)
3. Include all PostgreSQL and operator image references

### Step 4: Validate the Component

```bash
make validate
```

### Step 5: View the Component Descriptor

```bash
make show
```

Example output:
```yaml
components:
  - name: ocm.software/cloudnative-pg
    version: 1.24.1
    provider:
      name: ocm.software
    resources:
      - name: cloudnative-pg-operator
        type: ociImage
        version: 1.24.1
        access:
          imageReference: ghcr.io/cloudnative-pg/cloudnative-pg:1.24.1
      # ... more resources
```

## Using the Component

### Option 1: Push to OCM Repository

Push the component to your OCM repository (OCI registry):

```bash
# Push to GitHub Container Registry
OCM_REPO=ghcr.io/your-org/ocm make push

# Push to other registries
OCM_REPO=registry.example.com/ocm make push
```

### Option 2: Export as TAR Archive

```bash
ocm transfer componentversions ./build archive.tgz
```

### Option 3: Download Images Locally

Extract image references and download them:

```bash
# List all image resources
ocm get resources ./build -o yaml

# Download a specific image
ocm download resource ./build cloudnative-pg-operator
```

## Next Steps

- **Phase 3**: Configure operator and cluster templates in `config/`
- **Phase 4**: Add operator manifests as local resources
- **Phase 5**: Implement configuration validation schema
- **Phase 6**: Create example configurations for common scenarios

## Troubleshooting

### OCM CLI Not Found

Ensure the OCM CLI is installed and in your PATH:
```bash
which ocm
```

### Build Directory Already Exists

Clean and rebuild:
```bash
make clean
make build
```

### Invalid Component Descriptor

Validate YAML syntax:
```bash
yamllint component-constructor.yaml
```

Check for missing variables:
```bash
make info
```

## Additional Resources

- [OCM Documentation](https://ocm.software/docs/)
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [Component Constructor Format](https://ocm.software/docs/getting-started/create-component-version/)
