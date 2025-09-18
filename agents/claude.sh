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

    if [ "$using_custom_home" = false ]; then
        if [ -d "$HOME/.claude" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.claude:/home/deva/.claude")
        fi
        if [ -f "$HOME/.claude.json" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.claude.json:/home/deva/.claude.json")
        fi
    fi
    if [ -d "$(pwd)/.claude" ]; then
        DOCKER_ARGS+=("-v" "$(pwd)/.claude:$(pwd)/.claude")
    fi
}
