# shellcheck shell=bash

agent_prepare() {
    local -a args
    if [ $# -gt 0 ]; then
        args=("$@")
    else
        args=()
    fi
    AGENT_COMMAND=("claude")

    local has_dangerously=false
    if [ ${#args[@]} -gt 0 ]; then
        for arg in "${args[@]}"; do
            if [ "$arg" = "--dangerously-skip-permissions" ]; then
                has_dangerously=true
                break
            fi
        done
    fi
    if [ "$has_dangerously" = false ]; then
        AGENT_COMMAND+=("--dangerously-skip-permissions")
    fi

    if [ ${#args[@]} -gt 0 ]; then
        AGENT_COMMAND+=("${args[@]}")
    fi

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
