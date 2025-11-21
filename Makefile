# OCM CloudNativePG Package Makefile

# Configuration
OCM_REPO ?= ghcr.io/ocm/ocm-cnpg
COMPONENT_NAME ?= ocm.software/cloudnative-pg
PROVIDER_NAME ?= ocm.software

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
