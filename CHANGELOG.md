# Changelog

All notable changes to claude-code-yolo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2025-07-08

### Changed
- Refactored auth system and environment handling

## [0.3.0] - 2025-07-02

### Changed
- Streamlined Docker image build process
- Updated npm global installation path
- Enhanced CI pipeline with release workflow and version check
- Improved container registry configuration

## [0.2.6] - 2025-06-24

### Fixed
- Makefile registry inconsistency with ghcr.io default image

## [0.2.5] - 2025-06-25

### Changed
- Add note on `CLAUDE_CONFIG_DIR` and fix gcloud config symlink in entrypoint

## [0.2.4] - 2025-06-23

### Added
- Unified logging system for improved UX
- Clean output by default showing only authentication method
- Verbose mode displays model selection, proxy configuration, and debug info

### Fixed
- Argument parsing infinite loop in claude-yolo for --inspect and --ps options
- Duplicate argument handling causing inconsistent behavior with mixed options
- claude-trace --run-with syntax (removed unnecessary "claude" argument)
- Container shortcuts now properly exit after --ps command

### Changed
- Consolidated all claude-yolo argument parsing through single parse_args() function
- Enhanced claude-trace argument injection for proper --dangerously-skip-permissions placement
- Improved logging organization
- Updated documentation with logging capabilities and examples

### Performance
- Docker build caching in GitHub Actions (dual GHA + registry cache strategy)

## [0.2.3] - 2025-06-23

### Added
- Dynamic fallback UID/GID selection for root users

### Fixed
- Handle UID 0 (root user) case in docker-entrypoint.sh
- Add explicit github_token to claude-code-review action
- Handle UID=0 and GID=0 independently for security

### Changed
- Simplify root user handling with hardcoded 1000 fallback
- Remove redundant comments in UID/GID handling
- Run Claude review once per PR and on manual trigger

### Performance
- Docker build caching improvements in GitHub Actions

### Documentation
- Update logs and changelog for issue #19 caching fix
- Clarify root cause and solution for UID 0 handling
- Add OIDC token fix to dev log

## [0.2.2] - 2025-06-23

### Added
- Docker image update to ghcr.io with fallback to Docker Hub
- Note when falling back to Docker Hub image in installer

### Fixed
- Set shellcheck to error severity to prevent CI blocking

### Documentation
- Improve usage examples across all documentation

## [0.2.1] - 2025-06-23

### Fixed
- Move shellcheck to CI workflow, remove from release

## [0.2.0] - 2025-06-23

### Added
- --verbose flag to show environment info and pass to Docker

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
