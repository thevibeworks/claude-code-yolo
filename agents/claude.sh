# shellcheck shell=bash

# Load shared auth utilities
# shellcheck disable=SC1091
if [ -f "$(dirname "${BASH_SOURCE[0]}")/shared_auth.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/shared_auth.sh"
fi

agent_prepare() {
    local -a args
    if [ $# -gt 0 ]; then
        args=("$@")
    else
        args=()
    fi
    AGENT_COMMAND=("claude")

    # Parse auth method and filter remaining args using shared function
    parse_auth_args "claude" "${args[@]+"${args[@]}"}"
    local auth_method="$PARSED_AUTH_METHOD"
    # Safe array assignment that works with set -u
    local -a remaining_args=("${PARSED_REMAINING_ARGS[@]+"${PARSED_REMAINING_ARGS[@]}"}")

    local has_dangerously=false
    if [ ${#remaining_args[@]} -gt 0 ]; then
        for arg in "${remaining_args[@]}"; do
            if [ "$arg" = "--dangerously-skip-permissions" ]; then
                has_dangerously=true
                break
            fi
        done
    fi
    if [ "$has_dangerously" = false ]; then
        AGENT_COMMAND+=("--dangerously-skip-permissions")
    fi

    # Safe array expansion for remaining args
    AGENT_COMMAND+=("${remaining_args[@]+"${remaining_args[@]}"}")

    # Setup authentication
    setup_claude_auth "$auth_method"

    local using_custom_home=false
    if [ -n "${CONFIG_HOME:-}" ]; then
        using_custom_home=true
    fi

    if [ "$using_custom_home" = false ] && [ -z "${CONFIG_ROOT:-}" ]; then
        if [ -d "$HOME/.claude" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.claude:/home/deva/.claude")
        fi
        if [ -f "$HOME/.claude.json" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.claude.json:/home/deva/.claude.json")
        fi
    fi

    # Back-compat: if CONFIG_HOME was auto-selected and has no Claude creds,
    # but host creds exist, also mount host creds.
    if [ "$using_custom_home" = true ] && [ "${CONFIG_HOME_AUTO:-false}" = true ] && [ -z "${CONFIG_ROOT:-}" ]; then
        if [ ! -d "$CONFIG_HOME/.claude" ] && [ -d "$HOME/.claude" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.claude:/home/deva/.claude")
        fi
        if [ ! -f "$CONFIG_HOME/.claude.json" ] && [ -f "$HOME/.claude.json" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.claude.json:/home/deva/.claude.json")
        fi
    fi
    if [ -d "$(pwd)/.claude" ]; then
        DOCKER_ARGS+=("-v" "$(pwd)/.claude:$(pwd)/.claude")
    fi
}

setup_claude_auth() {
    local method="$1"

    case "$method" in
        claude)
            # Default Claude.ai OAuth - handled by existing mount logic
            ;;
        api-key)
            validate_anthropic_key || auth_error "ANTHROPIC_API_KEY not set for --auth-with api-key" \
                                                  "Set: export ANTHROPIC_API_KEY=your_api_key"
            DOCKER_ARGS+=("-e" "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
            ;;
        copilot)
            validate_github_token || auth_error "No GitHub token found for copilot auth" \
                                                "Run: copilot-api auth, or set GH_TOKEN=\$(gh auth token)"
            start_copilot_proxy

            DOCKER_ARGS+=("-e" "ANTHROPIC_BASE_URL=http://$COPILOT_HOST_MAPPING:$COPILOT_PROXY_PORT")
            DOCKER_ARGS+=("-e" "ANTHROPIC_API_KEY=dummy")

            # Auto-detect models if not already set
            if [ -z "${ANTHROPIC_MODEL:-}" ] || [ -z "${ANTHROPIC_SMALL_FAST_MODEL:-}" ]; then
                local models
                models=$(pick_copilot_models "http://$COPILOT_LOCALHOST_MAPPING:$COPILOT_PROXY_PORT")
                local main_model="${models%% *}"
                local fast_model="${models#* }"

                [ -z "${ANTHROPIC_MODEL:-}" ] && DOCKER_ARGS+=("-e" "ANTHROPIC_MODEL=$main_model")
                [ -z "${ANTHROPIC_SMALL_FAST_MODEL:-}" ] && DOCKER_ARGS+=("-e" "ANTHROPIC_SMALL_FAST_MODEL=$fast_model")
            fi

            # Configure proxy settings for container
            local no_proxy="$COPILOT_HOST_MAPPING,$COPILOT_LOCALHOST_MAPPING,127.0.0.1"
            DOCKER_ARGS+=("-e" "NO_PROXY=${NO_PROXY:+$NO_PROXY,}$no_proxy")
            DOCKER_ARGS+=("-e" "no_grpc_proxy=${NO_GRPC_PROXY:+$NO_GRPC_PROXY,}$no_proxy")
            ;;
        oat)
            # Claude OAuth token (experimental)
            if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
                auth_error "CLAUDE_CODE_OAUTH_TOKEN not set for --auth-with oat" \
                           "Set: export CLAUDE_CODE_OAUTH_TOKEN=your_token"
            fi
            DOCKER_ARGS+=("-e" "CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN")
            ;;
        bedrock)
            # AWS Bedrock
            DOCKER_ARGS+=("-e" "CLAUDE_CODE_USE_BEDROCK=1")
            if [ -d "$HOME/.aws" ]; then
                DOCKER_ARGS+=("-v" "$HOME/.aws:/home/deva/.aws:ro")
            fi
            if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
                DOCKER_ARGS+=("-e" "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID")
            fi
            if [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
                DOCKER_ARGS+=("-e" "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY")
            fi
            if [ -n "${AWS_SESSION_TOKEN:-}" ]; then
                DOCKER_ARGS+=("-e" "AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN")
            fi
            if [ -n "${AWS_REGION:-}" ]; then
                DOCKER_ARGS+=("-e" "AWS_REGION=$AWS_REGION")
            fi
            ;;
        vertex)
            # Google Vertex AI
            DOCKER_ARGS+=("-e" "CLAUDE_CODE_USE_VERTEX=1")
            if [ -d "$HOME/.config/gcloud" ]; then
                DOCKER_ARGS+=("-v" "$HOME/.config/gcloud:/home/deva/.config/gcloud:ro")
            fi
            if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
                DOCKER_ARGS+=("-v" "$GOOGLE_APPLICATION_CREDENTIALS:$GOOGLE_APPLICATION_CREDENTIALS:ro")
                DOCKER_ARGS+=("-e" "GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS")
            fi
            ;;
        *)
            auth_error "auth method '$method' not implemented"
            ;;
    esac
}
