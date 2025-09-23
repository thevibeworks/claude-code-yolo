
IMAGE_NAME := ghcr.io/thevibeworks/deva
TAG := latest
RUST_TAG := rust
DOCKERFILE := Dockerfile
RUST_DOCKERFILE := Dockerfile.rust
MAIN_IMAGE := $(IMAGE_NAME):$(TAG)
RUST_IMAGE := $(IMAGE_NAME):$(RUST_TAG)
CONTAINER_NAME := deva-$(shell basename $(PWD))-$(shell date +%s)
CLAUDE_CODE_VERSION := 1.0.119
CODEX_VERSION := 0.39.0

export DOCKER_BUILDKIT := 1

.DEFAULT_GOAL := help

.PHONY: build
build:
	@echo "🔨 Building Docker image with $(DOCKERFILE)..."
	docker build -f $(DOCKERFILE) --build-arg CLAUDE_CODE_VERSION=$(CLAUDE_CODE_VERSION) --build-arg CODEX_VERSION=$(CODEX_VERSION) -t $(MAIN_IMAGE) .
	@echo "✅ Build completed: $(MAIN_IMAGE)"

.PHONY: rebuild
rebuild:
	@echo "🔨 Rebuilding Docker image (no cache) with $(DOCKERFILE)..."
	docker build -f $(DOCKERFILE) --no-cache --build-arg CLAUDE_CODE_VERSION=$(CLAUDE_CODE_VERSION) --build-arg CODEX_VERSION=$(CODEX_VERSION) -t $(MAIN_IMAGE) .
	@echo "✅ Rebuild completed: $(MAIN_IMAGE)"


.PHONY: build-rust
build-rust:
	@echo "🔨 Building Rust Docker image..."
	docker build -f $(RUST_DOCKERFILE) --build-arg BASE_IMAGE=$(MAIN_IMAGE) -t $(RUST_IMAGE) .
	@echo "✅ Rust build completed: $(RUST_IMAGE)"

.PHONY: build-all
build-all: build build-rust
	@echo "✅ All images built successfully"

.PHONY: buildx
buildx:
	@echo "🔨 Building with docker buildx..."
	docker buildx build -f $(DOCKERFILE) --load --build-arg CLAUDE_CODE_VERSION=$(CLAUDE_CODE_VERSION) --build-arg CODEX_VERSION=$(CODEX_VERSION) -t $(MAIN_IMAGE) .
	@echo "✅ Buildx completed: $(MAIN_IMAGE)"

.PHONY: buildx-multi
buildx-multi:
	@echo "🔨 Building multi-arch images for amd64 and arm64..."
	docker buildx build -f $(DOCKERFILE) --platform linux/amd64,linux/arm64 \
		--build-arg CLAUDE_CODE_VERSION=$(CLAUDE_CODE_VERSION) \
		--build-arg CODEX_VERSION=$(CODEX_VERSION) \
		--push -t $(MAIN_IMAGE) .
	@echo "✅ Multi-arch build completed and pushed: $(MAIN_IMAGE)"

.PHONY: buildx-multi-rust
buildx-multi-rust:
	@echo "🔨 Building multi-arch Rust images for amd64 and arm64..."
	docker buildx build -f $(RUST_DOCKERFILE) --platform linux/amd64,linux/arm64 \
		--build-arg BASE_IMAGE=$(MAIN_IMAGE) \
		--push -t $(RUST_IMAGE) .
	@echo "✅ Multi-arch Rust build completed and pushed: $(RUST_IMAGE)"

.PHONY: buildx-multi-local
buildx-multi-local:
	@echo "🔨 Building multi-arch images locally..."
	docker buildx build --platform linux/amd64,linux/arm64 \
		--build-arg CLAUDE_CODE_VERSION=$(CLAUDE_CODE_VERSION) \
		--build-arg CODEX_VERSION=$(CODEX_VERSION) \
		-t $(MAIN_IMAGE) .
	@echo "✅ Multi-arch build completed locally: $(MAIN_IMAGE)"

.PHONY: clean
clean:
	@echo "🧹 Cleaning up Docker artifacts..."
	-docker rmi $(MAIN_IMAGE) 2>/dev/null || true
	-docker rmi $(RUST_IMAGE) 2>/dev/null || true
	-docker system prune -f
	@echo "✅ Cleanup completed"

.PHONY: clean-all
clean-all:
	@echo "🧹 Deep cleaning Docker artifacts and build cache..."
	-docker rmi $(MAIN_IMAGE) 2>/dev/null || true
	-docker rmi $(RUST_IMAGE) 2>/dev/null || true
	-docker builder prune -af
	-docker system prune -af --volumes
	@echo "✅ Deep cleanup completed"

.PHONY: shell
shell:
	@echo "🐚 Opening shell in $(MAIN_IMAGE)..."
	docker run --rm -it \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		--name $(CONTAINER_NAME) \
		$(MAIN_IMAGE) /bin/zsh

.PHONY: test
test:
	@echo "🧪 Testing $(MAIN_IMAGE)..."
	@echo "Testing claude command..."
	docker run --rm $(MAIN_IMAGE) claude --version
	@echo "Testing development tools..."
	docker run --rm $(MAIN_IMAGE) bash -c 'python --version && node --version && go version'
	@echo "✅ All tests passed"

.PHONY: test-rust
test-rust:
	@echo "🧪 Testing $(RUST_IMAGE)..."
	@echo "Testing Rust toolchain..."
	docker run --rm $(RUST_IMAGE) bash -c 'rustc --version && cargo --version && rustfmt --version && clippy-driver --version'
	@echo "Testing Rust tools..."
	docker run --rm $(RUST_IMAGE) bash -c 'cargo-watch --version && wasm-pack --version'
	@echo "✅ Rust tests passed"

.PHONY: test-local
test-local:
	@echo "🧪 Testing $(MAIN_IMAGE) with local directory..."
	docker run --rm -it \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		$(MAIN_IMAGE) bash -c 'pwd && ls -la && claude --version'

.PHONY: info
info:
	@echo "📊 Image information for $(MAIN_IMAGE):"
	@docker images $(MAIN_IMAGE) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
	@echo ""
	@echo "🔍 Image layers:"
	@docker history $(MAIN_IMAGE) --no-trunc

.PHONY: push
push:
	@echo "📤 Pushing $(MAIN_IMAGE) to registry..."
	docker push $(MAIN_IMAGE)
	@echo "✅ Push completed"

.PHONY: pull
pull:
	@echo "📥 Pulling $(MAIN_IMAGE) from registry..."
	docker pull $(MAIN_IMAGE)
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

.PHONY: version-check
version-check:
	@./scripts/version-check.sh

.PHONY: release-patch
release-patch:
	@./claude-yolo "Execute release workflow from @workflows/RELEASE.md for a **patch** release"

.PHONY: release-minor
release-minor:
	@./claude-yolo "Execute release workflow from @workflows/RELEASE.md for a **minor** release"

.PHONY: release-major
release-major:
	@./claude-yolo "Execute release workflow from @workflows/RELEASE.md for a **major** release"

.PHONY: help
help:
	@echo "deva.sh - Docker Build Shortcuts"
	@echo "==============================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@echo "  build                Build main Docker image"
	@echo "  build-rust           Build Rust Docker image"
	@echo "  build-all            Build all images"
	@echo "  rebuild              Rebuild without cache"
	@echo "  buildx               Build with buildx"
	@echo "  buildx-multi         Build multi-arch and push"
	@echo "  buildx-multi-rust    Build multi-arch Rust and push"
	@echo "  test                 Test main image"
	@echo "  test-rust            Test Rust image"
	@echo "  shell                Open shell in container"
	@echo "  clean                Clean up Docker artifacts"
	@echo "  clean-all            Deep clean with build cache"
	@echo "  push                 Push image to registry"
	@echo "  pull                 Pull image from registry"
	@echo "  info                 Show image information"
	@echo "  lint                 Lint Dockerfile"
	@echo ""
	@echo "Environment variables:"
	@echo "  IMAGE_NAME           Main image name (default: $(IMAGE_NAME))"
	@echo "  TAG                  Docker image tag (default: $(TAG))"
	@echo "  RUST_TAG             Rust image tag (default: $(RUST_TAG))"
	@echo "  DOCKERFILE           Dockerfile to use (default: $(DOCKERFILE))"
	@echo "  RUST_DOCKERFILE      Rust Dockerfile path (default: $(RUST_DOCKERFILE))"
	@echo "  CLAUDE_CODE_VERSION  Claude CLI version (default: $(CLAUDE_CODE_VERSION))"
	@echo "  CODEX_VERSION        Codex CLI version (default: $(CODEX_VERSION))"
	@echo ""
	@echo "Examples:"
	@echo "  make build                                    # Build main image"
	@echo "  make build-rust                               # Build Rust image"
	@echo "  make DOCKERFILE=$(RUST_DOCKERFILE) build         # Build with specific Dockerfile"
	@echo "  make TAG=dev build-all                        # Build all with custom tag"
	@echo "  make CLAUDE_CODE_VERSION=1.0.117 build       # Build with specific Claude version"
