# Changelog

All notable changes to claude-code-yolo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-06-21

### Added
- Initial release of claude-code-yolo Docker wrapper
- Dual-mode architecture: Local mode (default) and YOLO mode (Docker)
- Support for 4 authentication methods:
  - Claude App OAuth (`--claude`, `-c`)
  - Anthropic API Key (`--api-key`, `-a`)
  - AWS Bedrock (`--bedrock`, `-b`)
  - Google Vertex AI (`--vertex`, `-v`)
- Full development environment in Docker image:
  - Ubuntu 24.04 base
  - Python 3.12, Node.js 22, Go 1.22, Rust
  - Development tools: git, docker, aws, jq, ripgrep, fzf
  - Claude CLI and claude-trace pre-installed
- Automatic `--dangerously-skip-permissions` in YOLO mode
- Non-root user support with UID/GID mapping
- Authentication file mounting and permission handling
- Proxy support with automatic localhost translation
- Model alias system for easy model selection
- Docker socket mounting option (disabled by default)
- Shell access to container (`--shell`)
- Request tracing support (`--trace`)
- Dangerous directory detection with user confirmation prompt
- Quick install script for one-line setup
- Standalone `claude-yolo` script for convenient access
- Prefixed logging with `[claude.sh]` for better identification
- Updated documentation with claude-trace integration details

### Security
- Container isolation for safe execution
- Directory access limited to current working directory
- Non-root execution inside container
- Docker socket mounting disabled by default
- Warning system for dangerous directories (home, system directories) 