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
    AGENT_COMMAND=("codex")

    # Parse auth method and filter remaining args using shared function
    parse_auth_args "codex" "${args[@]+"${args[@]}"}"
    local auth_method="$PARSED_AUTH_METHOD"
    # Safe array assignment that works with set -u
    local -a remaining_args=("${PARSED_REMAINING_ARGS[@]+"${PARSED_REMAINING_ARGS[@]}"}")

    local has_dangerous=false
    local has_model=false

    if [ ${#remaining_args[@]} -gt 0 ]; then
        for ((i=0; i<${#remaining_args[@]}; i++)); do
            case "${remaining_args[$i]}" in
                --dangerously-bypass-approvals-and-sandbox)
                    has_dangerous=true
                    ;;
                -m|--model)
                    has_model=true
                    ((i++))
                    ;;
                -m*)
                    has_model=true
                    ;;
                --model=*)
                    has_model=true
                    ;;
            esac
        done
    fi

    if [ "$has_dangerous" = false ]; then
        AGENT_COMMAND+=("--dangerously-bypass-approvals-and-sandbox")
    fi
    if [ "$has_model" = false ]; then
        AGENT_COMMAND+=("-m" "${DEVA_DEFAULT_CODEX_MODEL:-gpt-5-codex}")
    fi

    # Safe array expansion for remaining args
    AGENT_COMMAND+=("${remaining_args[@]+"${remaining_args[@]}"}")

    DOCKER_ARGS+=("-p" "127.0.0.1:1455:1455")

    local using_custom_home=false
    if [ -n "${CONFIG_HOME:-}" ]; then
        using_custom_home=true
    fi

    local codex_home=""
    if [ "$using_custom_home" = false ] && [ -z "${CONFIG_ROOT:-}" ]; then
        if [ -d "$HOME/.codex" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.codex:/home/deva/.codex")
            codex_home="$HOME/.codex"
        fi
    else
        if [ -d "$CONFIG_HOME/.codex" ]; then
            codex_home="$CONFIG_HOME/.codex"
        fi
    fi

    # Back-compat: if CONFIG_HOME was auto-selected and has no Codex creds,
    # but host creds exist, also mount host creds.
    if [ "$using_custom_home" = true ] && [ "${CONFIG_HOME_AUTO:-false}" = true ] && [ -z "${CONFIG_ROOT:-}" ]; then
        if [ ! -d "$CONFIG_HOME/.codex" ] && [ -d "$HOME/.codex" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.codex:/home/deva/.codex")
            codex_home="$HOME/.codex"
        fi
    fi

    # If CONFIG_ROOT is active, detect Codex auth.json there for env stripping
    if [ -z "$codex_home" ] && [ -n "${CONFIG_ROOT:-}" ] && [ -f "$CONFIG_ROOT/codex/.codex/auth.json" ]; then
        codex_home="$CONFIG_ROOT/codex/.codex"
    fi

    # Strip conflicting env vars when OAuth auth.json exists
    local has_oauth_file=false
    if [ -n "$codex_home" ] && [ -f "$codex_home/auth.json" ]; then
        has_oauth_file=true
        strip_openai_env OPENAI_API_KEY
        strip_openai_env OPENAI_BASE_URL
        strip_openai_env OPENAI_ORGANIZATION
    fi

    # Setup authentication (after config mounting and stripping)
    # Skip oauth setup if we have existing auth.json - it would conflict
    if [ "$auth_method" = "chatgpt" ] && [ "$has_oauth_file" = true ]; then
        # Use existing OAuth file, no additional setup needed
        :
    else
        setup_codex_auth "$auth_method"
    fi
}

strip_openai_env() {
    local target="$1"
    local cleaned=()
    local i=0
    while [ $i -lt ${#DOCKER_ARGS[@]} ]; do
        if [ "${DOCKER_ARGS[$i]}" = "-e" ]; then
            local spec="${DOCKER_ARGS[$((i+1))]}"
            if [[ "$spec" == "$target" ]] || [[ "$spec" == "$target="* ]]; then
                i=$((i + 2))
                continue
            fi
            cleaned+=("-e" "$spec")
            i=$((i + 2))
        else
            cleaned+=("${DOCKER_ARGS[$i]}")
            i=$((i + 1))
        fi
    done
    DOCKER_ARGS=("${cleaned[@]}")
}

setup_codex_auth() {
    local method="$1"

    case "$method" in
        chatgpt)
            # Default ChatGPT OAuth - handled by existing mount logic
            ;;
        api-key)
            validate_openai_key || auth_error "OPENAI_API_KEY not set for --auth-with api-key" \
                                              "Set: export OPENAI_API_KEY=your_api_key"
            DOCKER_ARGS+=("-e" "OPENAI_API_KEY=$OPENAI_API_KEY")
            ;;
        copilot)
            validate_github_token || auth_error "No GitHub token found for copilot auth" \
                                                "Run: copilot-api auth, or set GH_TOKEN=\$(gh auth token)"
            start_copilot_proxy

            DOCKER_ARGS+=("-e" "OPENAI_BASE_URL=http://$COPILOT_HOST_MAPPING:$COPILOT_PROXY_PORT")
            DOCKER_ARGS+=("-e" "OPENAI_API_KEY=dummy")

            # Auto-detect models if not already set
            if [ -z "${OPENAI_MODEL:-}" ]; then
                local models
                models=$(pick_copilot_models "http://$COPILOT_LOCALHOST_MAPPING:$COPILOT_PROXY_PORT")
                local main_model="${models%% *}"
                # Use main model as default for Codex
                DOCKER_ARGS+=("-e" "OPENAI_MODEL=$main_model")
            fi

            # Configure proxy settings for container
            local no_proxy="$COPILOT_HOST_MAPPING,$COPILOT_LOCALHOST_MAPPING,127.0.0.1"
            DOCKER_ARGS+=("-e" "NO_PROXY=${NO_PROXY:+$NO_PROXY,}$no_proxy")
            DOCKER_ARGS+=("-e" "no_grpc_proxy=${NO_GRPC_PROXY:+$NO_GRPC_PROXY,}$no_proxy")
            ;;
        *)
            auth_error "auth method '$method' not implemented"
            ;;
    esac
}
