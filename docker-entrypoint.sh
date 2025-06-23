#!/bin/bash
set -e

CLAUDE_USER="${CLAUDE_USER:-claude}"
CLAUDE_UID="${CLAUDE_UID:-1001}"
CLAUDE_GID="${CLAUDE_GID:-1001}"
CLAUDE_HOME="${CLAUDE_HOME:-/home/claude}"

show_environment_info() {
    if [ "$VERBOSE" = "true" ]; then
        echo "Claude Code YOLO Environment"
        echo "================================"
        echo "Working Directory: $(pwd)"
        echo "Running as: $(whoami) (UID=$(id -u), GID=$(id -g))"
        echo "Python: $(python3 --version)"
        echo "Node.js: $(node --version 2>/dev/null || echo 'Not found')"
        echo "Rust: $(rustc --version | head -n1)"
        echo "Go: $(go version)"

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

        echo "Running as: $CLAUDE_USER (UID=$CLAUDE_UID, GID=$CLAUDE_GID)"
        echo "================================"
    fi
}

setup_nonroot_user() {
    # Align UID/GID with host user if provided
    local current_uid=$(id -u "$CLAUDE_USER")
    local current_gid=$(id -g "$CLAUDE_USER")

    # Handle UID=0 case (host user is root)
    if [ "$CLAUDE_UID" = "0" ]; then
        echo "[entrypoint] WARNING: Host user is root (UID=0). Using fallback UID 1000 for security."
        CLAUDE_UID=1000
    fi

    # Handle GID=0 case (host user in root group)
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
        chown -R "$CLAUDE_UID:$CLAUDE_GID" "$CLAUDE_HOME"
    fi

    [ "$VERBOSE" = "true" ] && echo "[entrypoint] setting up access to mounted volumes"

    # Make /root fully accessible - Claude needs permissions to work
    chmod 755 /root 2>/dev/null || true

    # Essential: Handle .claude directory
    if [ -d "/root/.claude" ]; then
        [ "$VERBOSE" = "true" ] && echo "[entrypoint] linking .claude"
        chmod -R 755 /root/.claude 2>/dev/null || true
        ln -sfn /root/.claude "$CLAUDE_HOME/.claude"
    fi

    # Essential: Handle .claude.json
    if [ -f "/root/.claude.json" ]; then
        [ "$VERBOSE" = "true" ] && echo "[entrypoint] linking .claude.json"
        chmod 644 /root/.claude.json 2>/dev/null || true
        ln -sfn /root/.claude.json "$CLAUDE_HOME/.claude.json"
    fi

    # Essential: Handle .config/gcloud directory for Google Vertex AI
    if [ -d "/root/.config/gcloud" ]; then
        [ "$VERBOSE" = "true" ] && echo "[entrypoint] linking .config/gcloud"
        mkdir -p "$CLAUDE_HOME/.config"
        chmod -R 755 /root/.config/gcloud 2>/dev/null || true
        ln -sfn /root/.config/gcloud "$CLAUDE_HOME/.config/gcloud"
    fi

    # Common: AWS credentials
    if [ -d "/root/.aws" ]; then
        [ "$VERBOSE" = "true" ] && echo "[entrypoint] linking .aws"
        chmod -R 755 /root/.aws 2>/dev/null || true
        ln -sfn /root/.aws "$CLAUDE_HOME/.aws"
    fi

    # Handle user-mounted volumes in /root/*
    # Users are responsible for setting appropriate permissions on mounted volumes
    # We only create symlinks without modifying permissions
    for item in /root/.*; do
        if [ -e "$item" ] && [ "$item" != "/root/." ] && [ "$item" != "/root/.." ]; then
            basename_item=$(basename "$item")
            case "$basename_item" in
            .claude | .aws | .config)
                continue
                ;;
            *)
                [ "$VERBOSE" = "true" ] && echo "[entrypoint] linking $basename_item (preserving permissions)"
                ln -sfn "$item" "$CLAUDE_HOME/$basename_item"
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

    local -a cmd=(gosu "$user" env)

    cmd+=("HOME=$CLAUDE_HOME" "PATH=$PATH")

    # Pass through proxy settings
    [ -n "$HTTP_PROXY" ] && cmd+=("HTTP_PROXY=$HTTP_PROXY")
    [ -n "$HTTPS_PROXY" ] && cmd+=("HTTPS_PROXY=$HTTPS_PROXY")
    [ -n "$NO_PROXY" ] && cmd+=("NO_PROXY=$NO_PROXY")

    # Pass through Anthropic settings
    [ -n "$ANTHROPIC_MODEL" ] && cmd+=("ANTHROPIC_MODEL=$ANTHROPIC_MODEL")
    [ -n "$ANTHROPIC_API_KEY" ] && cmd+=("ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")

    # Pass through AWS credentials for Bedrock
    [ -n "$AWS_ACCESS_KEY_ID" ] && cmd+=("AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID")
    [ -n "$AWS_SECRET_ACCESS_KEY" ] && cmd+=("AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY")
    [ -n "$AWS_SESSION_TOKEN" ] && cmd+=("AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN")
    [ -n "$AWS_REGION" ] && cmd+=("AWS_REGION=$AWS_REGION")
    [ -n "$AWS_DEFAULT_REGION" ] && cmd+=("AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION")
    [ -n "$AWS_PROFILE" ] && cmd+=("AWS_PROFILE=$AWS_PROFILE")

    # Pass through Google Cloud settings for Vertex AI
    [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && cmd+=("GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS")
    [ -n "$GOOGLE_CLOUD_PROJECT" ] && cmd+=("GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT")

    # Pass through Claude Code specific settings
    [ -n "$CLAUDE_CODE_USE_BEDROCK" ] && cmd+=("CLAUDE_CODE_USE_BEDROCK=$CLAUDE_CODE_USE_BEDROCK")
    [ -n "$CLAUDE_CODE_USE_VERTEX" ] && cmd+=("CLAUDE_CODE_USE_VERTEX=$CLAUDE_CODE_USE_VERTEX")
    [ -n "$CLAUDE_CODE_MAX_OUTPUT_TOKENS" ] && cmd+=("CLAUDE_CODE_MAX_OUTPUT_TOKENS=$CLAUDE_CODE_MAX_OUTPUT_TOKENS")
    [ -n "$ANTHROPIC_SMALL_FAST_MODEL" ] && cmd+=("ANTHROPIC_SMALL_FAST_MODEL=$ANTHROPIC_SMALL_FAST_MODEL")
    [ -n "$DISABLE_TELEMETRY" ] && cmd+=("DISABLE_TELEMETRY=$DISABLE_TELEMETRY")

    # Add the actual command and its arguments
    cmd+=("$@")

    exec "${cmd[@]}"
}

main() {
    export PATH="/root/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:$PATH"

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
        # Starting message removed for cleaner startup
        build_gosu_env_cmd "$CLAUDE_USER" "$CLAUDE_CMD" --dangerously-skip-permissions
    else
        cmd="$1"
        shift

        # Check if this is a Claude command (claude, claude-trace, etc.)
        if [ "$cmd" = "claude" ] || [ "$cmd" = "$CLAUDE_CMD" ]; then
            # Execution message removed for cleaner startup
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
        else
            # Execution message removed for cleaner startup
            build_gosu_env_cmd "$CLAUDE_USER" "$cmd" "$@"
        fi
    fi
}

main "$@"
