#!/bin/bash
set -e

DEVA_USER="${DEVA_USER:-deva}"
DEVA_UID="${DEVA_UID:-1001}"
DEVA_GID="${DEVA_GID:-1001}"
DEVA_HOME="${DEVA_HOME:-/home/deva}"
DEVA_AGENT="${DEVA_AGENT:-claude}"

get_claude_version() {
    local version=""
    for path in "/usr/local/bin/claude" "/usr/bin/claude" "$(command -v claude 2>/dev/null)"; do
        if [ -x "$path" ]; then
            version=$($path --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            break
        fi
    done
    echo "$version"
}

get_codex_version() {
    local version=""
    for path in "/usr/local/bin/codex" "/usr/bin/codex" "$(command -v codex 2>/dev/null)"; do
        if [ -x "$path" ]; then
            version=$($path --version 2>/dev/null | head -1)
            break
        fi
    done
    echo "$version"
}

show_environment_info() {
    local header="[deva]"
    case "$DEVA_AGENT" in
        claude)
            if [ -n "$CLAUDE_VERSION" ]; then
                header+=" Starting Claude Code v$CLAUDE_VERSION"
            else
                header+=" Claude Code (version detection failed)"
            fi
            ;;
        codex)
            if [ -n "$CODEX_VERSION" ]; then
                header+=" Starting Codex ($CODEX_VERSION)"
            else
                header+=" Codex CLI (version detection failed)"
            fi
            ;;
        *)
            header+=" Starting agent: $DEVA_AGENT"
            ;;
    esac
    echo "$header"

    if [ "$VERBOSE" = "true" ]; then
        echo ""
        echo "deva.sh YOLO Environment"
        echo "================================"
        echo "Agent: $DEVA_AGENT"
        echo "Working Directory: $(pwd)"
        echo "Running as: $(whoami) (UID=$(id -u), GID=$(id -g))"
        echo "Python: $(python3 --version 2>/dev/null || echo 'Not found')"
        echo "Node.js: $(node --version 2>/dev/null || echo 'Not found')"
        echo "Go: $(go version 2>/dev/null || echo 'Not found')"
        echo ""
        sleep 0.1

        if [ "$DEVA_AGENT" = "claude" ]; then
            local cli_path=""
            for path in "/usr/local/bin/claude" "/usr/bin/claude" "$(command -v claude 2>/dev/null)"; do
                if [ -x "$path" ]; then
                    cli_path="$path"
                    break
                fi
            done
            if [ -n "$cli_path" ]; then
                echo "Claude CLI: $($cli_path --version 2>/dev/null || echo 'Found but version failed')"
                echo "Claude location: $cli_path"
            else
                echo "Claude CLI not found in PATH"
            fi

            if [ -d "$DEVA_HOME/.claude" ]; then
                echo "Claude auth directory mounted"
                # shellcheck disable=SC2012
                ls -la "$DEVA_HOME/.claude" | head -5
            else
                echo "warning: Claude auth directory not found in $DEVA_HOME/.claude"
            fi
        else
            local codex_path=""
            for path in "/usr/local/bin/codex" "/usr/bin/codex" "$(command -v codex 2>/dev/null)"; do
                if [ -x "$path" ]; then
                    codex_path="$path"
                    break
                fi
            done
            if [ -n "$codex_path" ]; then
                echo "Codex CLI: $($codex_path --version 2>/dev/null || echo 'Found but version failed')"
                echo "Codex location: $codex_path"
            else
                echo "Codex CLI not found in PATH"
            fi

            if [ -d "$DEVA_HOME/.codex" ]; then
                echo "Codex auth directory mounted"
                # shellcheck disable=SC2012
                ls -la "$DEVA_HOME/.codex" | head -5
            else
                echo "warning: Codex auth directory not found in $DEVA_HOME/.codex"
            fi
        fi

        if [ -n "$grpc_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
            echo "Proxy configuration:"
            [ -n "$grpc_proxy" ] && echo "  gRPC: $grpc_proxy"
            [ -n "$HTTPS_PROXY" ] && echo "  HTTPS: $HTTPS_PROXY"
            [ -n "$HTTP_PROXY" ] && echo "  HTTP: $HTTP_PROXY"
        fi

        echo "Running as: $DEVA_USER (UID=$DEVA_UID, GID=$DEVA_GID)"
        echo "================================"
    fi
}

setup_nonroot_user() {
    local current_uid
    current_uid=$(id -u "$DEVA_USER")
    local current_gid
    current_gid=$(id -g "$DEVA_USER")

    if [ "$DEVA_UID" = "0" ]; then
        echo "[entrypoint] WARNING: Host UID is 0. Using fallback 1000." 
        DEVA_UID=1000
    fi
    if [ "$DEVA_GID" = "0" ]; then
        echo "[entrypoint] WARNING: Host GID is 0. Using fallback 1000." 
        DEVA_GID=1000
    fi

    if [ "$DEVA_GID" != "$current_gid" ]; then
        [ "$VERBOSE" = "true" ] && echo "[entrypoint] updating $DEVA_USER GID: $current_gid -> $DEVA_GID"
        if getent group "$DEVA_GID" >/dev/null 2>&1; then
            local existing_group
            existing_group=$(getent group "$DEVA_GID" | cut -d: -f1)
            usermod -g "$DEVA_GID" "$DEVA_USER" 2>/dev/null || true
            [ "$VERBOSE" = "true" ] && echo "[entrypoint] joined existing group $existing_group"
        else
            groupmod -g "$DEVA_GID" "$DEVA_USER"
        fi
    fi

    if [ "$DEVA_UID" != "$current_uid" ]; then
        [ "$VERBOSE" = "true" ] && echo "[entrypoint] updating $DEVA_USER UID: $current_uid -> $DEVA_UID"
        usermod -u "$DEVA_UID" -g "$DEVA_GID" "$DEVA_USER"
        chown -R "$DEVA_UID:$DEVA_GID" "$DEVA_HOME" 2>/dev/null || true
    fi

    chmod 755 /root 2>/dev/null || true
}

fix_rust_permissions() {
    # Ensure rustup/cargo dirs are writable by current DEVA_UID after UID remap
    local rh="/opt/rustup"
    local ch="/opt/cargo"
    if [ -d "$rh" ]; then chown -R "$DEVA_UID:$DEVA_GID" "$rh" 2>/dev/null || true; fi
    if [ -d "$ch" ]; then chown -R "$DEVA_UID:$DEVA_GID" "$ch" 2>/dev/null || true; fi
    # Ensure they exist to avoid runtime failures
    [ -d "$rh" ] || mkdir -p "$rh"
    [ -d "$ch" ] || mkdir -p "$ch"
}

build_gosu_env_cmd() {
    local user="$1"
    shift
    exec gosu "$user" env "HOME=$DEVA_HOME" "PATH=$PATH" "$@"
}

ensure_agent_binaries() {
    case "$DEVA_AGENT" in
        claude)
            if ! command -v claude >/dev/null 2>&1; then
                echo "error: Claude CLI not found in container"
                exit 1
            fi
            ;;
        codex)
            if ! command -v codex >/dev/null 2>&1; then
                echo "error: Codex CLI not found in container"
                exit 1
            fi
            ;;
    esac
}

main() {
    export PATH="/home/deva/.local/bin:/home/deva/.npm-global/bin:/root/.local/bin:/usr/local/go/bin:/opt/cargo/bin:/usr/local/cargo/bin:$PATH"
    # Prefer /opt paths used by deva-rust layer
    export RUSTUP_HOME="${RUSTUP_HOME:-/opt/rustup}"
    export CARGO_HOME="${CARGO_HOME:-/opt/cargo}"

    CLAUDE_VERSION="$(get_claude_version)"
    CODEX_VERSION="$(get_codex_version)"

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

    ensure_agent_binaries
    setup_nonroot_user
    fix_rust_permissions

    if [ $# -eq 0 ]; then
    if [ "$DEVA_AGENT" = "codex" ]; then
        build_gosu_env_cmd "$DEVA_USER" codex --dangerously-bypass-approvals-and-sandbox -m "${DEVA_DEFAULT_CODEX_MODEL:-gpt-5-codex}"
    else
        build_gosu_env_cmd "$DEVA_USER" claude --dangerously-skip-permissions
    fi
        return
    fi

    cmd="$1"
    shift

    if [ "$DEVA_AGENT" = "claude" ]; then
        if [ "$cmd" = "claude" ] || [ "$cmd" = "$(command -v claude 2>/dev/null)" ]; then
            build_gosu_env_cmd "$DEVA_USER" "$cmd" "$@" --dangerously-skip-permissions
        elif [ "$cmd" = "claude-trace" ]; then
            args=("$@")
            new_args=()
            for arg in "${args[@]}"; do
                if [ "$arg" = "--run-with" ]; then
                    new_args+=("--run-with" "--dangerously-skip-permissions")
                else
                    new_args+=("$arg")
                fi
            done
            build_gosu_env_cmd "$DEVA_USER" "$cmd" "${new_args[@]}"
        else
            build_gosu_env_cmd "$DEVA_USER" "$cmd" "$@"
        fi
    else
        build_gosu_env_cmd "$DEVA_USER" "$cmd" "$@"
    fi
}

main "$@"
