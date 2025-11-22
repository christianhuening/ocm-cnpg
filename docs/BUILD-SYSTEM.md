# Build System Guide

This guide explains how to use the build system for the CloudNativePG OCM component.

## Quick Start

```bash
# Build the component
make build

# Validate the build
make validate

# Show what was built
make show
```

## Version Management

### Viewing Supported Versions

```bash
# Show all supported versions
make versions
```

Output:
```
CloudNativePG Operator:
  1.24.1 (2024-11-15) - Latest stable release
  1.24.0 (2024-10-28) - Stable release
  1.23.3 (2024-09-20) - Previous stable

PostgreSQL:
  PostgreSQL 17 (17.2) - Latest major version with improved performance
  PostgreSQL 16 (16.6) - Current stable, recommended for production
  PostgreSQL 15 (15.10) - Stable release
  PostgreSQL 14 (14.15) - Long-term support
```

### Verifying Images

Before building or deploying, verify that all images are accessible:

```bash
make verify-images
```

This checks:
- Operator image: `ghcr.io/cloudnative-pg/cloudnative-pg:1.24.1`
- PostgreSQL images: versions 14, 15, 16, 17

### Listing Available Tags

To see what versions are available in the registry:

```bash
# Install crane first
brew install crane

# List available tags
make list-image-tags
```

## Building Components

### Standard Build

```bash
# Clean previous builds
make clean

# Build new component
make build
```

The component is built from:
- `component-constructor.yaml` - Component descriptor template
- `settings.yaml` - Version configuration
- `config/**/*.yaml` - Configuration templates

### Build with Custom Versions

Edit `settings.yaml`:

```yaml
CNPG_VERSION: "1.24.1"
PG_VERSION_17: "17"
PG_VERSION_16: "16"
PG_VERSION_15: "15"
PG_VERSION_14: "14"
```

Then rebuild:

```bash
make clean build
```

### Validate Build

```bash
# Validate component descriptor structure
make validate

# Show component details
make show

# Show build configuration
make info
```

## Documentation Generation

### Generate All Documentation

```bash
make docs
```

This creates three documentation files in `docs/generated/`:

1. **component.md** - Full component descriptor in YAML
2. **templates.md** - All configuration templates with examples
3. **resources.md** - List of all OCI images and configuration resources

### Generate Specific Documentation

```bash
# Only component descriptor
make docs-component

# Only configuration templates
make docs-config

# Only resource listings
make docs-resources
```

### Clean Generated Documentation

```bash
make docs-clean
```

**Note:** Generated documentation is excluded from git (`.gitignore`).

## Fetching Upstream Resources

Download the latest CloudNativePG manifests:

```bash
make fetch-resources
```

This downloads:
- Operator manifests from CloudNativePG releases
- Stored in `resources/downloaded/`

Useful for:
- Reference during development
- Comparing with packaged templates
- Offline builds

## Testing

### Quick Tests (No Kubernetes Required)

```bash
make test-quick
```

Runs:
- Component build
- Descriptor validation
- Template syntax checking

### Full Test Suite (Requires Docker/KIND)

```bash
make test
```

Runs:
- All quick tests
- KIND cluster creation
- Operator deployment
- PostgreSQL cluster deployment
- Health checks
- Cleanup

### Test Individual Components

```bash
# Test component structure
make test-component

# Test templates only
make test-templates

# Test in KIND cluster
make test-kind
```

### Debugging with KIND

Keep the KIND cluster running for debugging:

```bash
make test-kind-keep
```

Access the cluster:
```bash
kubectl --context kind-cnpg-test get pods -A
```

Clean up when done:
```bash
make test-clean
```

## Publishing

### Push to OCM Repository

```bash
# Set your repository
export OCM_REPO=ghcr.io/your-org/ocm-cnpg

# Push component
make push
```

Or configure in environment:

```bash
# In your shell profile
export OCM_REPO=ghcr.io/your-org/ocm-cnpg
```

Then simply:
```bash
make push
```

## Common Workflows

### Development Workflow

```bash
# 1. Make changes to templates
vim config/cluster/basic-cluster.yaml

# 2. Rebuild and validate
make clean build validate

# 3. Test templates
make test-templates

# 4. Full test if needed
make test
```

### Release Workflow

```bash
# 1. Update versions
vim versions.yaml  # Update version matrix
vim settings.yaml  # Update current versions

# 2. Verify images exist
make verify-images

# 3. Clean build
make clean all

# 4. Generate documentation
make docs

# 5. Run full tests
make test

# 6. Push to repository
make push
```

### Documentation Update Workflow

```bash
# 1. Make changes
vim config/cluster/*.yaml

# 2. Regenerate docs
make docs-clean docs

# 3. Review generated docs
cat docs/generated/templates.md
```

## Makefile Targets Reference

### Core Build
- `build` - Build OCM component archive
- `validate` - Validate component descriptor
- `clean` - Remove build artifacts
- `all` - Clean, build, and validate

### Information
- `help` - Show all available targets
- `info` - Show current build configuration
- `show` - Display component descriptor
- `versions` - Show supported versions

### Version Management
- `verify-images` - Check if images exist in registry
- `list-image-tags` - List available image tags (requires crane)

### Documentation
- `docs` - Generate all documentation
- `docs-component` - Component descriptor docs
- `docs-config` - Configuration template docs
- `docs-resources` - Resource listing docs
- `docs-clean` - Remove generated docs

### Testing
- `test` - Full test suite with KIND
- `test-quick` - Quick tests (no Kubernetes)
- `test-component` - Component structure tests
- `test-templates` - Template validation
- `test-kind` - Test with KIND cluster
- `test-kind-keep` - Test and keep cluster
- `test-clean` - Clean up test resources

### Resources
- `fetch-resources` - Download upstream manifests
- `push` - Push to OCM repository

## Configuration Files

### settings.yaml
Current version configuration used during build:

```yaml
COMPONENT_NAME: ocm.software/cloudnative-pg
PROVIDER_NAME: ocm.software
CNPG_VERSION: "1.24.1"
PG_VERSION_17: "17"
PG_VERSION_16: "16"
PG_VERSION_15: "15"
PG_VERSION_14: "14"
```

### versions.yaml
Version matrix with full metadata:
- Supported operator versions
- PostgreSQL version matrix
- Release dates and EOL
- Compatibility information
- Update policy

## Dependencies

### Required
- **OCM CLI** (0.33.0+) - Install from https://ocm.software
- **kubectl** - For template validation
- **Docker** - For image verification and KIND
- **KIND** - For Kubernetes tests

### Optional
- **yq** - Better version output formatting (`brew install yq`)
- **crane** - List image tags (`brew install crane`)

## Troubleshooting

### Build Fails with "OCM CLI not found"

```bash
# Install OCM CLI
brew install open-component-model/tap/ocm
# or download from https://ocm.software
```

### Image Verification Fails

```bash
# Ensure Docker is running
docker ps

# Check image manually
docker manifest inspect ghcr.io/cloudnative-pg/cloudnative-pg:1.24.1
```

### Template Validation Fails

```bash
# Test template manually
make build
ocm download resource ./build cluster-basic -O /tmp/test.yaml
kubectl apply --dry-run=client -f /tmp/test.yaml
```

### Tests Fail in KIND

```bash
# Keep cluster for debugging
make test-kind-keep

# Check cluster status
kubectl --context kind-cnpg-test get pods -A

# Clean up and retry
make test-clean
make test
```

## Best Practices

1. **Always verify images** before building: `make verify-images`
2. **Run quick tests** during development: `make test-quick`
3. **Full tests before pushing**: `make test && make push`
4. **Keep versions.yaml updated** with new releases
5. **Regenerate docs** after template changes: `make docs`
6. **Use semantic versioning** in settings.yaml
7. **Test in KIND** before production deployment

## Examples

### Example 1: Update to New Operator Version

```bash
# 1. Check available versions
make list-image-tags

# 2. Update settings.yaml
vim settings.yaml  # Change CNPG_VERSION to "1.24.2"

# 3. Verify new image exists
make verify-images

# 4. Rebuild
make clean build validate

# 5. Test
make test

# 6. Update version matrix
vim versions.yaml  # Add 1.24.2 to supported versions
```

### Example 2: Add New PostgreSQL Version

```bash
# 1. Update versions.yaml
vim versions.yaml  # Add PostgreSQL 18 entry

# 2. Update component-constructor.yaml
vim component-constructor.yaml  # Add pg-18 resource

# 3. Update settings.yaml
vim settings.yaml  # Add PG_VERSION_18

# 4. Rebuild and test
make clean build test
```

### Example 3: Validate Before Deploy

```bash
# Complete validation workflow
make clean           # Clean old builds
make verify-images   # Verify all images exist
make build          # Build component
make validate       # Validate structure
make test-templates # Validate all templates
make test-component # Test component structure
make docs           # Generate documentation
make test           # Full integration test
make push           # Push to repository
```

## See Also

- [Component Constructor](../component-constructor.yaml) - Component descriptor template
- [Settings File](../settings.yaml) - Version configuration
- [Version Matrix](../versions.yaml) - Supported versions
- [Configuration Guide](./configuration-guide.md) - Template usage guide
- [CLAUDE.md](../CLAUDE.md) - Full implementation plan
- [PHASE4-SUMMARY.md](../PHASE4-SUMMARY.md) - Phase 4 implementation details
