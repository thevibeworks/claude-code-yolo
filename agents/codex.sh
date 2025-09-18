# shellcheck shell=bash

agent_prepare() {
    local -a args
    if [ $# -gt 0 ]; then
        args=("$@")
    else
        args=()
    fi
    AGENT_COMMAND=("codex")

    local has_dangerous=false
    local has_model=false

    for ((i=0; i<${#args[@]}; i++)); do
        case "${args[$i]}" in
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

    if [ "$has_dangerous" = false ]; then
        AGENT_COMMAND+=("--dangerously-bypass-approvals-and-sandbox")
    fi
    if [ "$has_model" = false ]; then
        AGENT_COMMAND+=("-m" "${DEVA_DEFAULT_CODEX_MODEL:-gpt-5-codex}")
    fi

    if [ ${#args[@]} -gt 0 ]; then
        AGENT_COMMAND+=("${args[@]}")
    fi

    DOCKER_ARGS+=("-p" "127.0.0.1:1455:1455")

    local using_custom_home=false
    if [ -n "${CONFIG_HOME:-}" ]; then
        using_custom_home=true
    fi

    local codex_home=""
    if [ "$using_custom_home" = false ]; then
        if [ -d "$HOME/.codex" ]; then
            DOCKER_ARGS+=("-v" "$HOME/.codex:/home/deva/.codex")
            codex_home="$HOME/.codex"
        fi
    else
        if [ -d "$CONFIG_HOME/.codex" ]; then
            codex_home="$CONFIG_HOME/.codex"
        fi
    fi

    if [ -n "$codex_home" ] && [ -f "$codex_home/auth.json" ]; then
        strip_openai_env OPENAI_API_KEY
        strip_openai_env OPENAI_BASE_URL
        strip_openai_env OPENAI_ORGANIZATION
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
