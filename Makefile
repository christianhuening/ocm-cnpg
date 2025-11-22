# OCM CloudNativePG Package Makefile

# Configuration
OCM_REPO ?= ghcr.io/ocm/ocm-cnpg
COMPONENT_NAME ?= ocm.software/cloudnative-pg
PROVIDER_NAME ?= ocm.software

# Image Registry Configuration
# Override these to pull images from private registries
OPERATOR_REGISTRY ?= ghcr.io/cloudnative-pg
POSTGRESQL_REGISTRY ?= ghcr.io/cloudnative-pg

# Versions - these should be overridden via settings.yaml or environment
CNPG_VERSION ?= 1.24.1
PG_VERSION_17 ?= 17.2
PG_VERSION_16 ?= 16.6
PG_VERSION_15 ?= 15.10
PG_VERSION_14 ?= 14.15

# Build configuration
BUILD_DIR = ./build
SETTINGS_FILE ?= settings.yaml
COMPONENT_ARCHIVE = $(BUILD_DIR)/component-archive.ctf

# OCM CLI configuration
OCM = ocm
OCM_FLAGS =

.PHONY: help
help: ## Show this help message
	@echo "OCM CloudNativePG Package - Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: check-ocm
check-ocm: ## Check if OCM CLI is installed
	@which $(OCM) > /dev/null || (echo "Error: OCM CLI not found. Install from https://ocm.software/docs/cli-reference/download/cli/" && exit 1)
	@echo "OCM CLI found: $$($(OCM) version)"

.PHONY: clean
clean: ## Clean build artifacts
	rm -rf $(BUILD_DIR)
	rm -rf resources/downloaded

.PHONY: fetch-resources
fetch-resources: ## Download upstream CloudNativePG resources
	@echo "Fetching CloudNativePG manifests version $(CNPG_VERSION)..."
	@mkdir -p resources/downloaded
	@curl -sSL -o resources/downloaded/cnpg-operator-$(CNPG_VERSION).yaml \
		https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v$(CNPG_VERSION)/releases/cnpg-$(CNPG_VERSION).yaml || \
		echo "Warning: Could not fetch operator manifests for version $(CNPG_VERSION)"
	@echo "Resources fetched successfully"

.PHONY: validate
validate: check-ocm ## Validate component descriptor
	@echo "Validating component descriptor..."
	@if [ -d "$(BUILD_DIR)" ]; then \
		$(OCM) get componentversions $(BUILD_DIR) -o yaml > /dev/null && echo "Component descriptor is valid"; \
	else \
		echo "Error: Build directory not found. Run 'make build' first."; \
		exit 1; \
	fi

.PHONY: build
build: check-ocm ## Build OCM component archive
	@echo "Building OCM component archive..."
	@mkdir -p $(BUILD_DIR)
	@if [ -f "$(SETTINGS_FILE)" ]; then \
		echo "Using settings from $(SETTINGS_FILE)"; \
		$(OCM) add componentversions \
			--create \
			--file $(BUILD_DIR) \
			--settings $(SETTINGS_FILE) \
			./component-constructor.yaml; \
	else \
		echo "No settings file found, using defaults and environment variables"; \
		$(OCM) add componentversions \
			--create \
			--file $(BUILD_DIR) \
			./component-constructor.yaml \
			COMPONENT_NAME=$(COMPONENT_NAME) \
			PROVIDER_NAME=$(PROVIDER_NAME) \
			OPERATOR_REGISTRY=$(OPERATOR_REGISTRY) \
			POSTGRESQL_REGISTRY=$(POSTGRESQL_REGISTRY) \
			CNPG_VERSION=$(CNPG_VERSION) \
			PG_VERSION_17=$(PG_VERSION_17) \
			PG_VERSION_16=$(PG_VERSION_16) \
			PG_VERSION_15=$(PG_VERSION_15) \
			PG_VERSION_14=$(PG_VERSION_14); \
	fi
	@echo "Component archive created successfully at $(BUILD_DIR)"

.PHONY: show
show: ## Display component descriptor
	@if [ -d "$(BUILD_DIR)" ]; then \
		$(OCM) get componentversions $(BUILD_DIR) -o yaml; \
	else \
		echo "Error: Build directory not found. Run 'make build' first."; \
		exit 1; \
	fi

.PHONY: push
push: check-ocm ## Push component archive to OCM repository
	@echo "Pushing component archive to $(OCM_REPO)..."
	@if [ ! -d "$(BUILD_DIR)" ]; then \
		echo "Error: Build directory not found. Run 'make build' first."; \
		exit 1; \
	fi
	@$(OCM) transfer componentversions $(BUILD_DIR) $(OCM_REPO)
	@echo "Component pushed successfully to $(OCM_REPO)"

.PHONY: info
info: ## Show build configuration
	@echo "Build Configuration:"
	@echo "  Component Name: $(COMPONENT_NAME)"
	@echo "  Provider:       $(PROVIDER_NAME)"
	@echo "  OCM Repository: $(OCM_REPO)"
	@echo ""
	@echo "Image Registries:"
	@echo "  Operator:       $(OPERATOR_REGISTRY)"
	@echo "  PostgreSQL:     $(POSTGRESQL_REGISTRY)"
	@echo ""
	@echo "Versions:"
	@echo "  CNPG Operator:  $(CNPG_VERSION)"
	@echo "  PostgreSQL 17:  $(PG_VERSION_17)"
	@echo "  PostgreSQL 16:  $(PG_VERSION_16)"
	@echo "  PostgreSQL 15:  $(PG_VERSION_15)"
	@echo "  PostgreSQL 14:  $(PG_VERSION_14)"
	@echo ""
	@echo "Build Directory:  $(BUILD_DIR)"
	@echo "Settings File:    $(SETTINGS_FILE)"

.PHONY: all
all: clean build validate ## Clean, build and validate
	@echo "Build complete!"

# ============================================
# Version Management
# ============================================

.PHONY: versions
versions: ## Show supported versions from versions.yaml
	@echo "Supported Versions:"
	@echo ""
	@if command -v yq > /dev/null 2>&1; then \
		echo "CloudNativePG Operator:"; \
		yq '.operator.supported[] | "  " + .version + " (" + .release_date + ") - " + .notes' versions.yaml; \
		echo ""; \
		echo "PostgreSQL:"; \
		yq '.postgresql.versions[] | "  PostgreSQL " + .major + " (" + .full_version + ") - " + .notes' versions.yaml; \
	else \
		echo "  Install 'yq' for formatted output: brew install yq"; \
		echo "  Raw version file:"; \
		cat versions.yaml; \
	fi

.PHONY: verify-images
verify-images: ## Verify that all referenced images exist and are accessible
	@echo "Verifying image references..."
	@echo ""
	@echo "Operator image:"
	@docker manifest inspect $(OPERATOR_REGISTRY)/cloudnative-pg:$(CNPG_VERSION) > /dev/null 2>&1 && \
		echo "  ✓ $(OPERATOR_REGISTRY)/cloudnative-pg:$(CNPG_VERSION)" || \
		echo "  ✗ $(OPERATOR_REGISTRY)/cloudnative-pg:$(CNPG_VERSION) - NOT FOUND"
	@echo ""
	@echo "PostgreSQL images:"
	@for version in 17 16 15 14; do \
		docker manifest inspect $(POSTGRESQL_REGISTRY)/postgresql:$$version > /dev/null 2>&1 && \
			echo "  ✓ $(POSTGRESQL_REGISTRY)/postgresql:$$version" || \
			echo "  ✗ $(POSTGRESQL_REGISTRY)/postgresql:$$version - NOT FOUND"; \
	done
	@echo ""
	@echo "Image verification complete"

.PHONY: list-image-tags
list-image-tags: ## List available tags for operator and PostgreSQL images
	@echo "This requires crane or skopeo. Install with:"
	@echo "  brew install crane"
	@echo ""
	@if command -v crane > /dev/null 2>&1; then \
		echo "CloudNativePG Operator tags (latest 10):"; \
		crane ls $(OPERATOR_REGISTRY)/cloudnative-pg | sort -V | tail -10; \
		echo ""; \
		echo "PostgreSQL tags (latest 10):"; \
		crane ls $(POSTGRESQL_REGISTRY)/postgresql | grep -E '^[0-9]+$$' | sort -V | tail -10; \
	else \
		echo "Please install crane to list remote tags"; \
	fi

# ============================================
# Documentation Generation
# ============================================

.PHONY: docs
docs: ## Generate documentation from component and configurations
	@echo "Generating documentation..."
	@mkdir -p docs/generated
	@$(MAKE) docs-component
	@$(MAKE) docs-config
	@$(MAKE) docs-resources
	@echo "Documentation generated in docs/generated/"

.PHONY: docs-component
docs-component: build ## Generate component descriptor documentation
	@echo "Generating component documentation..."
	@echo "# Component Descriptor" > docs/generated/component.md
	@echo "" >> docs/generated/component.md
	@echo "## Component Information" >> docs/generated/component.md
	@echo "" >> docs/generated/component.md
	@echo '```yaml' >> docs/generated/component.md
	@$(OCM) get componentversions $(BUILD_DIR) -o yaml >> docs/generated/component.md
	@echo '```' >> docs/generated/component.md
	@echo "✓ Component documentation generated"

.PHONY: docs-config
docs-config: build ## Generate configuration template documentation
	@echo "Generating configuration documentation..."
	@mkdir -p docs/generated
	@echo "# Configuration Templates" > docs/generated/templates.md
	@echo "" >> docs/generated/templates.md
	@echo "This document describes all available configuration templates included in the OCM component." >> docs/generated/templates.md
	@echo "" >> docs/generated/templates.md
	@for template in operator-configmap monitoring-queries cluster-basic cluster-ha cluster-backup-s3 cluster-backup-gcs cluster-backup-azure cluster-monitoring; do \
		echo "## Template: $$template" >> docs/generated/templates.md; \
		echo "" >> docs/generated/templates.md; \
		echo '```yaml' >> docs/generated/templates.md; \
		$(OCM) download resource $(BUILD_DIR) $$template 2>/dev/null >> docs/generated/templates.md || echo "Error extracting $$template" >> docs/generated/templates.md; \
		echo '```' >> docs/generated/templates.md; \
		echo "" >> docs/generated/templates.md; \
	done
	@echo "✓ Configuration documentation generated"

.PHONY: docs-resources
docs-resources: build ## Generate resource list documentation
	@echo "Generating resource documentation..."
	@echo "# OCM Resources" > docs/generated/resources.md
	@echo "" >> docs/generated/resources.md
	@echo "## Container Images" >> docs/generated/resources.md
	@echo "" >> docs/generated/resources.md
	@$(OCM) get resources $(BUILD_DIR) -o wide | grep -E "(NAME|ociImage)" >> docs/generated/resources.md || true
	@echo "" >> docs/generated/resources.md
	@echo "## Configuration Templates" >> docs/generated/resources.md
	@echo "" >> docs/generated/resources.md
	@$(OCM) get resources $(BUILD_DIR) -o wide | grep -E "(NAME|yaml)" >> docs/generated/resources.md || true
	@echo "✓ Resource documentation generated"

.PHONY: docs-clean
docs-clean: ## Clean generated documentation
	@rm -rf docs/generated
	@echo "✓ Documentation cleaned"

# ============================================
# Testing targets
# ============================================

.PHONY: test
test: ## Run complete test suite (requires Docker, KIND, kubectl)
	@echo "Running test suite..."
	@./test/test-suite.sh

.PHONY: test-quick
test-quick: ## Run quick tests (component build and validation only)
	@echo "Running quick tests..."
	@SKIP_K8S_TESTS=true ./test/test-suite.sh

.PHONY: test-component
test-component: build validate ## Test component build and structure
	@echo "Testing component structure..."
	@$(OCM) get resources $(BUILD_DIR) -o yaml > /dev/null && echo "✓ Component resources valid"
	@echo "✓ Component tests passed"

.PHONY: test-templates
test-templates: build ## Extract and validate all configuration templates
	@echo "Testing configuration templates..."
	@mkdir -p /tmp/ocm-test-templates
	@for template in operator-configmap monitoring-queries cluster-basic cluster-ha cluster-backup-s3 cluster-monitoring; do \
		echo "  Testing $$template..."; \
		$(OCM) download resource $(BUILD_DIR) $$template -O /tmp/ocm-test-templates/$$template.yaml 2>/dev/null || \
			(echo "✗ Failed to extract $$template" && exit 1); \
		kubectl apply --dry-run=client -f /tmp/ocm-test-templates/$$template.yaml > /dev/null 2>&1 || \
			(echo "✗ Invalid YAML in $$template" && exit 1); \
		echo "  ✓ $$template valid"; \
	done
	@rm -rf /tmp/ocm-test-templates
	@echo "✓ All templates valid"

.PHONY: test-kind
test-kind: ## Create KIND cluster and deploy test resources
	@echo "Running Kubernetes tests in KIND..."
	@KIND_CLUSTER_NAME=cnpg-test CLEANUP_ON_SUCCESS=true ./test/test-suite.sh

.PHONY: test-kind-keep
test-kind-keep: ## Create KIND cluster and keep it running (for debugging)
	@echo "Running Kubernetes tests in KIND (keeping cluster)..."
	@KIND_CLUSTER_NAME=cnpg-test CLEANUP_ON_SUCCESS=false ./test/test-suite.sh

.PHONY: test-clean
test-clean: ## Clean up test resources
	@echo "Cleaning up test resources..."
	@kind delete cluster --name cnpg-test 2>/dev/null || true
	@rm -rf /tmp/ocm-test-templates
	@echo "✓ Test cleanup complete"
