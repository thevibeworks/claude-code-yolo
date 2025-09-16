#!/bin/bash
set -e

CLAUDE_USER="${CLAUDE_USER:-claude}"
CLAUDE_UID="${CLAUDE_UID:-1001}"
CLAUDE_GID="${CLAUDE_GID:-1001}"
CLAUDE_HOME="${CLAUDE_HOME:-/home/claude}"

get_claude_version() {
    local claude_version=""
    for path in "/usr/local/bin/claude" "/usr/bin/claude" "$(which claude 2>/dev/null)"; do
        if [ -x "$path" ]; then
            claude_version=$($path --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            break
        fi
    done
    echo "$claude_version"
}

show_environment_info() {
    if [ -n "$CLAUDE_VERSION" ]; then
        echo "[claude-yolo] Starting Claude Code v$CLAUDE_VERSION"
    else
        echo "[claude-yolo] Claude Code (version detection failed)"
    fi

    if [ "$VERBOSE" = "true" ]; then
        echo ""
        echo "Claude Code YOLO Environment"
        echo "================================"
        echo "Working Directory: $(pwd)"
        echo "Running as: $(whoami) (UID=$(id -u), GID=$(id -g))"
        echo "Python: $(python3 --version)"
        echo "Node.js: $(node --version 2>/dev/null || echo 'Not found')"
        echo "Go: $(go version)"
        echo ""
        # Force flush and small delay to prevent terminal buffering issues
        sleep 0.1

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
            echo "Claude auth directory found (legacy /root mount)"
            ls -la /root/.claude/ | head -5
        elif [ -d "$CLAUDE_HOME/.claude" ]; then
            echo "Claude auth directory found"
            ls -la "$CLAUDE_HOME/.claude/" | head -5
        else
            echo "warning: Claude auth directory not found"
        fi

        if [ -n "$ANTHROPIC_MODEL" ]; then
            echo "Model: $ANTHROPIC_MODEL"
        fi

        if [ -n "$grpc_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
            echo "Proxy configured:"
            [ -n "$grpc_proxy" ] && echo "  gRPC: $grpc_proxy"
            [ -n "$HTTPS_PROXY" ] && echo "  HTTPS: $HTTPS_PROXY"
            [ -n "$HTTP_PROXY" ] && echo "  HTTP: $HTTP_PROXY"
        fi

        echo "Running as: $CLAUDE_USER (UID=$CLAUDE_UID, GID=$CLAUDE_GID)"
        echo "================================"
    fi
}

setup_nonroot_user() {
    # Align UID/GID with host user if provided
    local current_uid=$(id -u "$CLAUDE_USER")
    local current_gid=$(id -g "$CLAUDE_USER")

    if [ "$CLAUDE_UID" = "0" ]; then
        echo "[entrypoint] WARNING: Host user is root (UID=0). Using fallback UID 1000 for security."
        CLAUDE_UID=1000
    fi

    if [ "$CLAUDE_GID" = "0" ]; then
        echo "[entrypoint] WARNING: Host user is in root group (GID=0). Using fallback GID 1000 for security."
        CLAUDE_GID=1000
    fi

    if [ "$CLAUDE_GID" != "$current_gid" ]; then
        [ "$VERBOSE" = "true" ] && echo "[entrypoint] updating $CLAUDE_USER GID: $current_gid -> $CLAUDE_GID"
        if getent group "$CLAUDE_GID" >/dev/null 2>&1; then
            existing_group=$(getent group "$CLAUDE_GID" | cut -d: -f1)
            [ "$VERBOSE" = "true" ] && echo "[entrypoint] GID $CLAUDE_GID already taken by group: $existing_group"
            [ "$VERBOSE" = "true" ] && echo "[entrypoint] Adding $CLAUDE_USER to existing group $existing_group"
            usermod -g "$CLAUDE_GID" "$CLAUDE_USER" 2>/dev/null || true
        else
            groupmod -g "$CLAUDE_GID" "$CLAUDE_USER"
        fi
    fi

    if [ "$CLAUDE_UID" != "$current_uid" ]; then
        [ "$VERBOSE" = "true" ] && echo "[entrypoint] updating $CLAUDE_USER UID: $current_uid -> $CLAUDE_UID"
        usermod -u "$CLAUDE_UID" -g "$CLAUDE_GID" "$CLAUDE_USER"
        # Re-own entire home; ignore read-only bind mounts to avoid noisy errors.
        chown -R "$CLAUDE_UID:$CLAUDE_GID" "$CLAUDE_HOME" 2>/dev/null || true
    fi

    [ "$VERBOSE" = "true" ] && echo "[entrypoint] setting up access to mounted volumes"

    # Make /root fully accessible - Claude needs permissions to work
    chmod 755 /root 2>/dev/null || true

    # New mounts go directly to /home/claude, so they're already in the right place
    [ "$VERBOSE" = "true" ] && [ -d "$CLAUDE_HOME/.claude" ] && echo "[entrypoint] .claude found in $CLAUDE_HOME"
    [ "$VERBOSE" = "true" ] && [ -f "$CLAUDE_HOME/.claude.json" ] && echo "[entrypoint] .claude.json found in $CLAUDE_HOME"
    [ "$VERBOSE" = "true" ] && [ -d "$CLAUDE_HOME/.aws" ] && echo "[entrypoint] .aws found in $CLAUDE_HOME"
    [ "$VERBOSE" = "true" ] && [ -d "$CLAUDE_HOME/.config/gcloud" ] && echo "[entrypoint] .config/gcloud found in $CLAUDE_HOME"

    # Handle user-mounted volumes in /root/*
    # Users are responsible for setting appropriate permissions on mounted volumes
    # We only create symlinks without modifying permissions
    for item in /root/.*; do
        if [ -e "$item" ] && [ "$item" != "/root/." ] && [ "$item" != "/root/.." ]; then
            basename_item=$(basename "$item")
            case "$basename_item" in
            .claude | .aws | .config | .ssh)
                continue
                ;;
            *)
                target="$CLAUDE_HOME/$basename_item"
                if [ -e "$target" ]; then
                    [ "$VERBOSE" = "true" ] && echo "[entrypoint] skip $basename_item – already exists in $CLAUDE_HOME"
                else
                    [ "$VERBOSE" = "true" ] && echo "[entrypoint] linking $basename_item (preserving permissions)"
                    ln -sfn "$item" "$target" 2>/dev/null || true
                fi
                ;;
            esac
        fi
    done
}

build_gosu_env_cmd() {
    # Build gosu command with environment variables
    # Usage: build_gosu_env_cmd <user> <command> [args...]
    local user="$1"
    shift

    exec gosu "$user" env "HOME=$CLAUDE_HOME" "PATH=$PATH" "$@"
}

main() {
    export PATH="/home/claude/.local/bin:/home/claude/.npm-global/bin:/root/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:$PATH"

    export CLAUDE_VERSION="$(get_claude_version)"

    if [ -n "$ANTHROPIC_BASE_URL" ]; then
        case "$ANTHROPIC_BASE_URL" in
            http://localhost:*|http://localhost/*|http://127.0.0.1:*|http://127.0.0.1/*)
                export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL/localhost/host.docker.internal}"
                export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL/127.0.0.1/host.docker.internal}"
                ;;
        esac
    fi

    show_environment_info

    if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        cd "$WORKDIR"
    fi

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

    # Always run as non-root claude user
    setup_nonroot_user

    if [ $# -eq 0 ]; then
        build_gosu_env_cmd "$CLAUDE_USER" "$CLAUDE_CMD" --dangerously-skip-permissions
    else
        cmd="$1"
        shift

        # Check if this is a Claude command (claude, claude-trace, etc.)
        if [ "$cmd" = "claude" ] || [ "$cmd" = "$CLAUDE_CMD" ]; then
            build_gosu_env_cmd "$CLAUDE_USER" "$cmd" "$@" --dangerously-skip-permissions
        elif [ "$cmd" = "claude-trace" ]; then
            # Execution message removed for cleaner startup
            # claude-trace --include-all-requests --run-with [args]
            # We need to inject --dangerously-skip-permissions as first argument after --run-with
            args=("$@")
            new_args=()
            i=0
            while [ $i -lt ${#args[@]} ]; do
                if [ "${args[$i]}" = "--run-with" ]; then
                    new_args+=("--run-with" "--dangerously-skip-permissions")
                else
                    new_args+=("${args[$i]}")
                fi
                i=$((i + 1))
            done
            build_gosu_env_cmd "$CLAUDE_USER" "$cmd" "${new_args[@]}"
        elif [ "$cmd" = "/usr/bin/zsh" ] || [ "$cmd" = "/bin/zsh" ] || [ "$cmd" = "zsh" ]; then
            build_gosu_env_cmd "$CLAUDE_USER" "$cmd"
        else
            build_gosu_env_cmd "$CLAUDE_USER" "$cmd" "$@"
        fi
    fi
}

main "$@"
