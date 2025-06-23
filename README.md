# Claude Code YOLO

Docker-based Claude Code CLI with full development capabilities and host isolation.

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/lroolle/claude-code-yolo/main/install.sh | bash

```


```bash
# Navigate to your project and run
cd ~/projects/my-project
claude-yolo
```

## ⚠️ CRITICAL SAFETY WARNING

Claude will have **FULL ACCESS** to the current workspace and ALL subdirectories.

Always `cd` to a specific project directory first!

**NEVER run `--yolo` mode in:**
- Your home directory (`$HOME`)
- System directories (`/`, `/etc`, `/usr`, etc.)
- Any directory containing sensitive data


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
claude-yolo                         # Run in current directory

# Using claude.sh for more control
claude.sh --yolo                    # YOLO mode
claude.sh                           # Local mode (no Docker)
claude.sh --auth-with api-key       # Use API key(may have to rerun `/login`)
claude.sh --auth-with bedrock       # Use AWS Bedrock
claude.sh --auth-with vertex        # Use Google Vertex AI
claude.sh --shell                   # Open shell in container
claude.sh --help                    # Show all options
```

## Authentication Methods

- **Claude App** (default): Uses `~/.claude` OAuth - `--auth-with claude`
  - Run `/login` in claude-code, open the oauth link, then paste the code back in the terminal
- **API Key**: Set `ANTHROPIC_API_KEY` environment variable - `--auth-with api-key`
  - If OAuth exists, use `/login` in Claude to switch to API key auth
- **AWS Bedrock**: Uses `~/.aws` credentials - `--auth-with bedrock`
- **Google Vertex**: Uses `~/.config/gcloud` credentials - `--auth-with vertex`

## GitHub CLI Authentication

For GitHub operations (creating PRs, managing repos), set the `GH_TOKEN` environment variable:

```bash
# Set your GitHub token
export GH_TOKEN="ghp_xxxxxxxxxxxx"

# Now gh commands work in containers
claude-yolo
# Inside container: gh pr create, gh issue list, etc.
```

**Note**: This avoids mounting `~/.config/gh/` which fails due to secure keyring storage in modern GitHub CLI versions.

## Custom Volume Mounting

You can mount additional configuration files or directories using the `-v` flag:

```bash
# Mount Git configuration
claude-yolo -v ~/.gitconfig:/root/.gitconfig

# Mount SSH keys (read-only)
claude-yolo -v ~/.ssh:/root/.ssh:ro

# Resume with SSH keys and tracing enabled
claude-yolo -v ~/.ssh:/root/.ssh:ro --trace  --continue

# Multiple mounts
claude-yolo -v ~/tools:/tools -v ~/data:/data

# Mount custom tool configs
claude-yolo -v ~/.config/gh:/root/.config/gh
claude-yolo -v ~/.terraform.d:/root/.terraform.d
```

**Note**: Volumes mounted to `/root/*` are automatically symlinked to `/home/claude/*` for non-root user access.

## Key Features

- **Full Dev Environment**: Python, Node.js, Go, Rust, and common tools pre-installed
- **Proxy Support**: Automatic `localhost` → `host.docker.internal` translation
- **Model Selection**: Use any Claude model via `ANTHROPIC_MODEL` env var
- **Request Tracing**: Debug with `--trace` flag using claude-trace
- **Docker Socket**: Optional mounting with `CLAUDE_YOLO_DOCKER_SOCKET=true`


### Request Tracing by @badlogic `claude-trace`

Claude Code YOLO integrates with [claude-trace](https://github.com/badlogic/lemmy/tree/main/apps/claude-trace) for detailed request logging and debugging.

## Docker Images

Claude Code YOLO is available from multiple container registries:

```bash
# GitHub Container Registry (recommended, primary)
docker pull ghcr.io/lroolle/claude-code-yolo:latest

# Docker Hub (fallback)
docker pull lroolle/claude-code-yolo:latest

# Use specific registry
DOCKER_IMAGE=lroolle/claude-code-yolo claude-yolo
```

## Manual Setup

```bash
# Clone repository
git clone https://github.com/lroolle/claude-code-yolo.git
cd claude-code-yolo

# Build from source (optional)
make build

# Run directly
./claude.sh --yolo
```

## Inspired by

- **[anthropics/claude-code](https://github.com/anthropics/claude-code)** - Official Claude Code CLI
- **[meal/claude-code-cli](https://github.com/meal/claude-code-cli)** - Containerized Claude Code with ready-to-use Docker setup
- **[gagarinyury/claude-code-root-runner](https://github.com/gagarinyury/claude-code-root-runner)** - Root privilege bypass for Claude Code using temporary users
- **[textcortex/claude-code-sandbox](https://github.com/textcortex/claude-code-sandbox)** - Full sandbox environment with web UI and autonomous workflows
