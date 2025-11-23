# Makefile for building custom PostgreSQL images with extensions

# Configuration
REGISTRY ?= my-registry.com
PG_VERSION ?= 16
PGVECTOR_VERSION ?= 0.5.1
TIMESCALEDB_VERSION ?= 2.13.0

# Image names
IMAGE_BASE = postgresql
IMAGE_TIMESCALEDB = $(IMAGE_BASE)-timescaledb
IMAGE_PGVECTOR = $(IMAGE_BASE)-pgvector

# Tags
TAG_TIMESCALEDB = $(PG_VERSION)-timescaledb$(TIMESCALEDB_VERSION)
TAG_PGVECTOR = $(PG_VERSION)-pgvector$(PGVECTOR_VERSION)

.PHONY: help
help: ## Show this help message
	@echo "Custom PostgreSQL Images - Build Targets"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Configuration:"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  PG_VERSION=$(PG_VERSION)"

.PHONY: build-all
build-all: build-timescaledb build-pgvector ## Build all custom images

.PHONY: build-timescaledb
build-timescaledb: ## Build PostgreSQL + TimescaleDB image
	@echo "Building TimescaleDB image..."
	docker build \
		--build-arg PG_VERSION=$(PG_VERSION) \
		-t $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(TAG_TIMESCALEDB) \
		-t $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(PG_VERSION) \
		-f Dockerfile.timescaledb \
		.
	@echo "✓ Built $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(TAG_TIMESCALEDB)"

.PHONY: build-pgvector
build-pgvector: ## Build PostgreSQL + pgvector image
	@echo "Building pgvector image..."
	docker build \
		--build-arg PG_VERSION=$(PG_VERSION) \
		--build-arg PGVECTOR_VERSION=$(PGVECTOR_VERSION) \
		-t $(REGISTRY)/$(IMAGE_PGVECTOR):$(TAG_PGVECTOR) \
		-t $(REGISTRY)/$(IMAGE_PGVECTOR):$(PG_VERSION) \
		-f Dockerfile.pgvector \
		.
	@echo "✓ Built $(REGISTRY)/$(IMAGE_PGVECTOR):$(TAG_PGVECTOR)"

.PHONY: push-all
push-all: push-timescaledb push-pgvector ## Push all custom images

.PHONY: push-timescaledb
push-timescaledb: ## Push TimescaleDB image to registry
	@echo "Pushing TimescaleDB image..."
	docker push $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(TAG_TIMESCALEDB)
	docker push $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(PG_VERSION)
	@echo "✓ Pushed $(REGISTRY)/$(IMAGE_TIMESCALEDB)"

.PHONY: push-pgvector
push-pgvector: ## Push pgvector image to registry
	@echo "Pushing pgvector image..."
	docker push $(REGISTRY)/$(IMAGE_PGVECTOR):$(TAG_PGVECTOR)
	docker push $(REGISTRY)/$(IMAGE_PGVECTOR):$(PG_VERSION)
	@echo "✓ Pushed $(REGISTRY)/$(IMAGE_PGVECTOR)"

.PHONY: test-timescaledb
test-timescaledb: ## Test TimescaleDB image
	@echo "Testing TimescaleDB image..."
	@docker run --rm $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(PG_VERSION) \
		postgres --version
	@docker run --rm $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(PG_VERSION) \
		psql --version
	@echo "✓ TimescaleDB image tests passed"

.PHONY: test-pgvector
test-pgvector: ## Test pgvector image
	@echo "Testing pgvector image..."
	@docker run --rm $(REGISTRY)/$(IMAGE_PGVECTOR):$(PG_VERSION) \
		postgres --version
	@docker run --rm $(REGISTRY)/$(IMAGE_PGVECTOR):$(PG_VERSION) \
		psql --version
	@echo "✓ pgvector image tests passed"

.PHONY: list
list: ## List built images
	@echo "Custom PostgreSQL Images:"
	@docker images $(REGISTRY)/$(IMAGE_TIMESCALEDB) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
	@docker images $(REGISTRY)/$(IMAGE_PGVECTOR) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

.PHONY: clean
clean: ## Remove built images
	@echo "Removing custom images..."
	-docker rmi $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(TAG_TIMESCALEDB) 2>/dev/null
	-docker rmi $(REGISTRY)/$(IMAGE_TIMESCALEDB):$(PG_VERSION) 2>/dev/null
	-docker rmi $(REGISTRY)/$(IMAGE_PGVECTOR):$(TAG_PGVECTOR) 2>/dev/null
	-docker rmi $(REGISTRY)/$(IMAGE_PGVECTOR):$(PG_VERSION) 2>/dev/null
	@echo "✓ Cleaned up custom images"
