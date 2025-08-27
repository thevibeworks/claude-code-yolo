# Claude Code YOLO

Docker-based Claude Code CLI with full development capabilities and host isolation.

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/thevibeworks/claude-code-yolo/main/install.sh | bash

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
claude.sh --auth-with oat -p "prompt" # Use OAuth token (experimental, non-interactive)
claude.sh --auth-with api-key       # Use API key(may have to rerun `/login`)
claude.sh --auth-with bedrock       # Use AWS Bedrock
claude.sh --auth-with vertex        # Use Google Vertex AI
claude.sh --shell                   # Open shell in container
claude.sh --host-net                # Host networking (Linux only)
claude.sh --help                    # Show all options
```

## Authentication Methods

- **Claude App** (default): Uses `~/.claude` OAuth - `--auth-with claude`
  - Run `/login` in claude-code, open the oauth link, then paste the code back in the terminal
- **OAuth Token**: Uses `CLAUDE_CODE_OAUTH_TOKEN` environment variable - `--auth-with oat` **[EXPERIMENTAL]**
  - Generate with `claude setup-token`, requires context files for Claude history
  - **Limitation**: Only works with `-p` flag (non-interactive mode)
- **API Key**: Set `ANTHROPIC_API_KEY` environment variable - `--auth-with api-key`
  - If OAuth exists, use `/login` in Claude to switch to API key auth
- **AWS Bedrock**: Uses `~/.aws` credentials - `--auth-with bedrock`
- **Google Vertex**: Uses `~/.config/gcloud` credentials - `--auth-with vertex`

### Custom Configuration Directory

Use a custom Claude config home instead of the default `~/.claude` and `~/.claude.json`:

```bash
# Use custom config directory home, should contains both ~/.claude.json and ~/.claude
claude-yolo --config ~/work-claude
```

This is useful for:
- Separate auth sessions for different projects
- Isolating Claude configurations

### OAuth Token Setup **[EXPERIMENTAL]**

For token-based authentication (with limitations):

```bash
# Generate OAuth token (run locally)
claude setup-token

# Set token and use (NON-INTERACTIVE ONLY)
export CLAUDE_CODE_OAUTH_TOKEN="your_token_here"
claude.sh --oat -p "your prompt"            # Local mode with token
claude.sh --yolo --oat -p "your prompt"     # YOLO mode with token

# Or inline
CLAUDE_CODE_OAUTH_TOKEN="your_token" claude.sh --oat -p "your prompt"
```

**Current Limitations**:
- Only works with `-p` flag (non-interactive mode)
- Interactive mode not supported (claude CLI limitation)

**Use Cases**:
- CI/CD automation with specific prompts
- Scripted Claude interactions
- Non-interactive batch processing

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

## Configuration Files

Claude YOLO supports configuration files to persist your volume mounts, environment variables, and settings. Following the XDG Base Directory specification:

```bash
# Configuration files are loaded in order (later files override earlier):
1. $XDG_CONFIG_HOME/claude-yolo/.claude-yolo   # Global config (default: ~/.config/claude-yolo/.claude-yolo)
2. ~/.claude-yolo                        # Legacy global location
3. .claude-yolo                          # Project-specific config
4. .claude-yolo.local                    # Local overrides (gitignored)
```

Example `.claude-yolo` file:
```bash
# Git integration
VOLUME=~/.ssh:/home/claude/.ssh:ro
VOLUME=~/.gitconfig:/home/claude/.gitconfig:ro

# Environment settings
ENV=NODE_ENV=development
ENV=DEBUG=myapp:*

# Pass through host env (either form works)
ENV=GH_TOKEN
ENV=${GH_TOKEN}

# Claude settings
ANTHROPIC_MODEL=sonnet-4
USE_TRACE=true
```

See `.claude-yolo.example` and `.claude-yolo.full` for more examples.

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
- **Docker Socket**: Optional mounting with `CCYOLO_DOCKER_SOCKET=true`


### Request Tracing by @badlogic `claude-trace`

Claude Code YOLO integrates with [claude-trace](https://github.com/badlogic/lemmy/tree/main/apps/claude-trace) for detailed request logging and debugging.

## Docker Images

Claude Code YOLO is available from multiple container registries:

```bash
# GitHub Container Registry (recommended, primary)
docker pull ghcr.io/thevibeworks/ccyolo:latest

# Docker Hub (fallback)
docker pull thevibeworks/ccyolo:latest

# Use specific registry
CCYOLO_DOCKER_IMAGE=thevibeworks/ccyolo claude-yolo
```

## Manual Setup

```bash
# Clone repository
git clone https://github.com/thevibeworks/claude-code-yolo.git
cd claude-code-yolo

# Build from source (optional)
make build

# Run directly
./claude.sh --yolo
```

### Custom Claude Version

```bash
make CLAUDE_CODE_VERSION=1.0.45 build  # Specific version
make CLAUDE_CODE_VERSION=latest build  # Latest version
```

## Inspired by

- **[anthropics/claude-code](https://github.com/anthropics/claude-code)** - Official Claude Code CLI
- **[meal/claude-code-cli](https://github.com/meal/claude-code-cli)** - Containerized Claude Code with ready-to-use Docker setup
- **[gagarinyury/claude-code-root-runner](https://github.com/gagarinyury/claude-code-root-runner)** - Root privilege bypass for Claude Code using temporary users
- **[textcortex/claude-code-sandbox](https://github.com/textcortex/claude-code-sandbox)** - Full sandbox environment with web UI and autonomous workflows
