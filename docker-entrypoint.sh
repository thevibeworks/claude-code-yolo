#!/bin/bash
set -e

# Environment variables for non-root mode
CLAUDE_USER="${CLAUDE_USER:-claude}"
CLAUDE_UID="${CLAUDE_UID:-1001}"
CLAUDE_GID="${CLAUDE_GID:-1001}"
CLAUDE_HOME="${CLAUDE_HOME:-/home/claude}"
USE_NONROOT="${USE_NONROOT:-false}"

show_environment_info() {
    echo "Claude Code YOLO Environment"
    echo "================================"
    echo "Working Directory: $(pwd)"
    echo "Running as: $(whoami) (UID=$(id -u), GID=$(id -g))"
    echo "Python: $(python3 --version)"

    # Initialize development environment
    export PATH="/root/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:$PATH"
    echo "Node.js: $(node --version 2>/dev/null || echo 'Not found')"
    echo "Rust: $(rustc --version | head -n1)"
    echo "Go: $(go version)"

    # Find Claude CLI - prioritize system-wide installation
    CLAUDE_PATH=""
    for path in "/usr/local/bin/claude" "/usr/bin/claude" "$(which claude 2>/dev/null)"; do
        if [ -x "$path" ]; then
            CLAUDE_PATH="$path"
            break
        fi
    done

    if [ -n "$CLAUDE_PATH" ]; then
        echo "Claude: $($CLAUDE_PATH --version 2>/dev/null || echo 'Found but version failed')"
        echo "Claude location: $CLAUDE_PATH"
    else
        echo "Claude: Not found in PATH"
        echo "Searching for Claude..."
        find /usr -name "claude" -type f 2>/dev/null | head -3 || true
    fi

    if [ -d "/root/.claude" ]; then
        echo "Claude auth directory found"
        ls -la /root/.claude/ | head -5
    else
        echo "warning: Claude auth directory not found at /root/.claude"
    fi

    if [ -n "$ANTHROPIC_MODEL" ]; then
        echo "Model: $ANTHROPIC_MODEL"
    fi

    if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
        echo "Proxy configured"
    fi

    if [ "$USE_NONROOT" = "true" ]; then
        echo "Non-root mode: $CLAUDE_USER (UID=$CLAUDE_UID, GID=$CLAUDE_GID)"
    else
        echo "Root mode: Running with --dangerously-skip-permissions"
    fi

    echo "================================"
}

setup_nonroot_user() {
    # Align UID/GID with host user if provided
    local current_uid=$(id -u "$CLAUDE_USER")
    local current_gid=$(id -g "$CLAUDE_USER")

    if [ "$CLAUDE_GID" != "$current_gid" ]; then
        echo "[entrypoint] updating $CLAUDE_USER GID: $current_gid -> $CLAUDE_GID"
        # Check if target GID is already taken by another group
        if getent group "$CLAUDE_GID" >/dev/null 2>&1; then
            existing_group=$(getent group "$CLAUDE_GID" | cut -d: -f1)
            echo "[entrypoint] GID $CLAUDE_GID already taken by group: $existing_group"
            echo "[entrypoint] Adding $CLAUDE_USER to existing group $existing_group"
            usermod -g "$CLAUDE_GID" "$CLAUDE_USER" 2>/dev/null || true
        else
            groupmod -g "$CLAUDE_GID" "$CLAUDE_USER"
        fi
    fi

    if [ "$CLAUDE_UID" != "$current_uid" ]; then
        echo "[entrypoint] updating $CLAUDE_USER UID: $current_uid -> $CLAUDE_UID"
        usermod -u "$CLAUDE_UID" -g "$CLAUDE_GID" "$CLAUDE_USER"
        # Update ownership of user home directory
        chown -R "$CLAUDE_UID:$CLAUDE_GID" "$CLAUDE_HOME"
    fi

    # Handle authentication files - grant permissions instead of copying
    # This preserves bidirectional sync with host
    echo "[entrypoint] granting claude user access to mounted auth directories"

    # Create symlinks in claude's home that point to the mounted directories
    # AND make the mounted directories accessible
    if [ -d "/root/.claude" ]; then
        echo "[entrypoint] setting permissions on /root/.claude for claude user access"
        # Make /root readable by claude user
        chmod 755 /root 2>/dev/null || true
        # Make .claude directory and contents readable
        chmod -R 755 /root/.claude 2>/dev/null || true
        # Create symlink for convenience
        ln -sfn /root/.claude "$CLAUDE_HOME/.claude"
        echo "[entrypoint] created symlink: $CLAUDE_HOME/.claude -> /root/.claude"
    fi

    if [ -f "/root/.claude.json" ]; then
        echo "[entrypoint] setting permissions on /root/.claude.json"
        chmod 644 /root/.claude.json 2>/dev/null || true
        ln -sfn /root/.claude.json "$CLAUDE_HOME/.claude.json"
    fi

    if [ -d "/root/.aws" ]; then
        echo "[entrypoint] setting permissions on /root/.aws"
        chmod -R 755 /root/.aws 2>/dev/null || true
        ln -sfn /root/.aws "$CLAUDE_HOME/.aws"
    fi

    if [ -d "/root/.config/gcloud" ]; then
        echo "[entrypoint] setting permissions on /root/.config/gcloud"
        chmod 755 /root/.config 2>/dev/null || true
        chmod -R 755 /root/.config/gcloud 2>/dev/null || true
        mkdir -p "$CLAUDE_HOME/.config"
        ln -sfn /root/.config/gcloud "$CLAUDE_HOME/.config/gcloud"
    fi
}

main() {
    # Set up environment before showing info
    export PATH="/root/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:$PATH"

    show_environment_info

    if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        cd "$WORKDIR"
    fi

    # Find Claude CLI executable - prioritize system-wide installation
    CLAUDE_CMD=""
    for path in "/usr/local/bin/claude" "/usr/bin/claude" "$(which claude 2>/dev/null)"; do
        if [ -x "$path" ]; then
            CLAUDE_CMD="$path"
            break
        fi
    done

    if [ -z "$CLAUDE_CMD" ]; then
        echo "error: Claude CLI not found! Searched common locations:"
        echo "   - /usr/local/bin/claude"
        echo "   - /usr/bin/claude"
        echo "   - PATH: $PATH"
        exit 1
    fi

    # Handle non-root mode
    if [ "$USE_NONROOT" = "true" ]; then
        setup_nonroot_user

        if [ $# -eq 0 ]; then
            echo "Starting Claude Code as $CLAUDE_USER with YOLO powers..."
            exec gosu "$CLAUDE_USER" env HOME="$CLAUDE_HOME" PATH="$PATH" "$CLAUDE_CMD" --dangerously-skip-permissions
        else
            cmd="$1"
            shift

            if [ "$cmd" = "claude" ] || [ "$cmd" = "$CLAUDE_CMD" ]; then
                echo "Executing Claude as $CLAUDE_USER with YOLO powers: $cmd $@"
                exec gosu "$CLAUDE_USER" env HOME="$CLAUDE_HOME" PATH="$PATH" "$cmd" "$@" --dangerously-skip-permissions
            else
                echo "Executing as $CLAUDE_USER: $cmd $@"
                exec gosu "$CLAUDE_USER" env HOME="$CLAUDE_HOME" PATH="$PATH" "$cmd" "$@"
            fi
        fi
    else
        if [ $# -eq 0 ]; then
            echo "Starting Claude Code in root mode with YOLO powers..."
            exec "$CLAUDE_CMD" --dangerously-skip-permissions
        else
            cmd="$1"
            if [ "$cmd" = "claude" ] || [ "$cmd" = "$CLAUDE_CMD" ]; then
                echo "Executing Claude in root mode with YOLO powers: $@"
                exec "$@" --dangerously-skip-permissions
            else
                echo "Executing: $@"
                exec "$@"
            fi
        fi
    fi
}

main "$@"
