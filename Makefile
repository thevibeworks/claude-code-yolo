
IMAGE_NAME := lroolle/claude-code-yolo
TAG := latest
CONTAINER_NAME := claude-code-yolo-$(shell basename $(PWD))-$(shell date +%s)

export DOCKER_BUILDKIT := 1

.DEFAULT_GOAL := help

.PHONY: build
build:
	@echo "🔨 Building Claude Code YOLO Docker image..."
	docker build -t $(IMAGE_NAME):$(TAG) .
	@echo "✅ Build completed: $(IMAGE_NAME):$(TAG)"

.PHONY: rebuild
rebuild:
	@echo "🔨 Rebuilding Claude Code YOLO Docker image (no cache)..."
	docker build --no-cache -t $(IMAGE_NAME):$(TAG) .
	@echo "✅ Rebuild completed: $(IMAGE_NAME):$(TAG)"

.PHONY: buildx
buildx:
	@echo "🔨 Building with docker buildx..."
	docker buildx build --load -t $(IMAGE_NAME):$(TAG) .
	@echo "✅ Buildx completed: $(IMAGE_NAME):$(TAG)"

.PHONY: buildx-multi
buildx-multi:
	@echo "🔨 Building multi-arch images for amd64 and arm64..."
	docker buildx build --platform linux/amd64,linux/arm64 \
		--push -t $(IMAGE_NAME):$(TAG) .
	@echo "✅ Multi-arch build completed and pushed: $(IMAGE_NAME):$(TAG)"

.PHONY: buildx-multi-local
buildx-multi-local:
	@echo "🔨 Building multi-arch images locally..."
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(IMAGE_NAME):$(TAG) .
	@echo "✅ Multi-arch build completed locally: $(IMAGE_NAME):$(TAG)"

.PHONY: clean
clean:
	@echo "🧹 Cleaning up Docker artifacts..."
	-docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true
	-docker system prune -f
	@echo "✅ Cleanup completed"

.PHONY: clean-all
clean-all:
	@echo "🧹 Deep cleaning Docker artifacts and build cache..."
	-docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true
	-docker builder prune -af
	-docker system prune -af --volumes
	@echo "✅ Deep cleanup completed"

.PHONY: shell
shell:
	@echo "🐚 Opening shell in $(IMAGE_NAME):$(TAG)..."
	docker run --rm -it \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME):$(TAG) /bin/zsh

.PHONY: test
test:
	@echo "🧪 Testing $(IMAGE_NAME):$(TAG)..."
	@echo "Testing claude command..."
	docker run --rm $(IMAGE_NAME):$(TAG) claude --version
	@echo "Testing development tools..."
	docker run --rm $(IMAGE_NAME):$(TAG) bash -c 'python --version && node --version && go version && rustc --version'
	@echo "✅ All tests passed"

.PHONY: test-local
test-local:
	@echo "🧪 Testing $(IMAGE_NAME):$(TAG) with local directory..."
	docker run --rm -it \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		$(IMAGE_NAME):$(TAG) bash -c 'pwd && ls -la && claude --version'

.PHONY: info
info:
	@echo "📊 Image information for $(IMAGE_NAME):$(TAG):"
	@docker images $(IMAGE_NAME):$(TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
	@echo ""
	@echo "🔍 Image layers:"
	@docker history $(IMAGE_NAME):$(TAG) --no-trunc

.PHONY: push
push:
	@echo "📤 Pushing $(IMAGE_NAME):$(TAG) to registry..."
	docker push $(IMAGE_NAME):$(TAG)
	@echo "✅ Push completed"

.PHONY: pull
pull:
	@echo "📥 Pulling $(IMAGE_NAME):$(TAG) from registry..."
	docker pull $(IMAGE_NAME):$(TAG)
	@echo "✅ Pull completed"

.PHONY: build-test
build-test: build test
	@echo "✅ Build and test completed successfully"

.PHONY: dev
dev: build shell

.PHONY: context-size
context-size:
	@echo "📏 Build context size:"
	@du -sh . --exclude='.git' --exclude='node_modules' --exclude='.claude-trace'

.PHONY: lint
lint:
	@echo "🔍 Linting Dockerfile..."
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Dockerfile; \
		echo "✅ Dockerfile linting completed"; \
	else \
		echo "⚠️  hadolint not found. Install with: brew install hadolint"; \
		echo "   Or run in Docker: docker run --rm -i hadolint/hadolint < Dockerfile"; \
	fi

.PHONY: help
help:
	@echo "Claude Code YOLO - Docker Build Shortcuts"
	@echo "=========================================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  %-15s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Environment variables:"
	@echo "  IMAGE_NAME     Docker image name (default: $(IMAGE_NAME))"
	@echo "  TAG            Docker image tag (default: $(TAG))"
	@echo ""
	@echo "Examples:"
	@echo "  make build                    # Build the image"
	@echo "  make rebuild                  # Rebuild without cache"
	@echo "  make shell                    # Open shell in container"
	@echo "  make test                     # Test image functionality"
	@echo "  make TAG=dev build            # Build with custom tag"
	@echo "  make clean                    # Clean up Docker artifacts"
