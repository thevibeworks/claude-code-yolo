# Claude Code YOLO

Docker-based Claude Code CLI with full development capabilities and host isolation.

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/lroolle/claude-code-yolo/main/install.sh | bash

# Navigate to your project and run
cd ~/projects/my-project
claude-yolo .
```

## ⚠️ CRITICAL SAFETY WARNING

**NEVER run `--yolo` mode in:**
- Your home directory (`$HOME`)
- System directories (`/`, `/etc`, `/usr`, etc.)
- Any directory containing sensitive data

Claude will have **FULL ACCESS** to the current directory and ALL subdirectories. Always `cd` to a specific project directory first!

## How It Works

Claude Code YOLO solves the permission friction of Claude CLI by running it inside a Docker container with `--dangerously-skip-permissions`. Here's how:

1. **Container Isolation**: Claude runs in a Docker container, not on your host system
2. **Directory Mounting**: Only your current directory is mounted into the container
3. **Authentication Passthrough**: Your credentials (`~/.claude`, `~/.aws`, etc.) are securely mounted
4. **Non-root Execution**: Runs as a non-root user inside container with UID/GID mapping
5. **Safety Checks**: Warns before running in dangerous directories like `$HOME`

This gives you full Claude Code power without compromising your system security.

## Usage

The installer provides two commands:
- `claude-yolo` - Quick alias for YOLO mode (recommended)
- `claude.sh` - Full wrapper with all options

```bash
# YOLO mode (Docker) - recommended
claude-yolo .                       # Run in current directory

# Using claude.sh for more control
claude.sh --yolo .                  # YOLO mode
claude.sh .                         # Local mode (no Docker)
claude.sh -a .                      # Use API key
claude.sh -b .                      # Use AWS Bedrock
claude.sh --shell                   # Open shell in container
claude.sh --help                    # Show all options
```

## Authentication Methods

- **Claude App** (default): Uses `~/.claude` OAuth
- **API Key** (`-a`): Set `ANTHROPIC_API_KEY` environment variable
- **AWS Bedrock** (`-b`): Uses `~/.aws` credentials
- **Google Vertex** (`-v`): Uses `~/.config/gcloud` credentials

## Key Features

- **Full Dev Environment**: Python, Node.js, Go, Rust, and common tools pre-installed
- **Proxy Support**: Automatic `localhost` → `host.docker.internal` translation
- **Model Selection**: Use any Claude model via `ANTHROPIC_MODEL` env var
- **Request Tracing**: Debug with `--trace` flag using claude-trace
- **Docker Socket**: Optional mounting with `CLAUDE_YOLO_DOCKER_SOCKET=true`

## Manual Setup

```bash
# Clone repository
git clone https://github.com/lroolle/claude-code-yolo.git
cd claude-code-yolo

# Build from source (optional)
make build

# Run directly
./claude.sh --yolo .
```

## Inspired by

- **[anthropics/claude-code](https://github.com/anthropics/claude-code)** - Official Claude Code CLI
- **[meal/claude-code-cli](https://github.com/meal/claude-code-cli)** - Containerized Claude Code with ready-to-use Docker setup
- **[gagarinyury/claude-code-root-runner](https://github.com/gagarinyury/claude-code-root-runner)** - Root privilege bypass for Claude Code using temporary users
- **[textcortex/claude-code-sandbox](https://github.com/textcortex/claude-code-sandbox)** - Full sandbox environment with web UI and autonomous workflows
