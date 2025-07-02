#!/bin/bash
set -e

# Claude Starter Script with Docker Support
# Runs Claude Code CLI locally or in a Docker container for safe execution

VERSION="0.3.0"
DOCKER_IMAGE="${DOCKER_IMAGE:-ghcr.io/lroolle/claude-code-yolo}"
DOCKER_TAG="${DOCKER_TAG:-latest}"

DEFAULT_ANTHROPIC_MODEL="sonnet-4"
DEFAULT_ANTHROPIC_SMALL_FAST_MODEL="haiku-3-5"
DEFAULT_AWS_REGION="us-west-2"

USE_DOCKER="${CLAUDE_YOLO_DOCKER:-false}"

show_help() {
    echo "Claude Code YOLO Wrapper - Run Claude CLI with flexible authentication and safe YOLO."
    echo ""
    echo "Usage: $0 [options] [claude-arguments...]"
    echo ""
    echo "This script runs Claude CLI either locally or in a Docker container with YOLO mode."
    echo ""
    echo "Options:"
    echo "  --trace                     Use claude-trace for logging"
    echo "  --verbose                   Show verbose output including environment info"
    echo "  --help, -h                  Show this help message"
    echo "  --version                   Show version information"
    echo "  --yolo                      YOLO mode: Run Claude in Docker (safe but powerful)"
    echo "  --shell                     Open a shell in the Docker container"
    echo ""
    echo "Authentication Options:"
    echo "  --auth-with METHOD          Set authentication method:"
    echo "                              claude    - Claude app authentication (OAuth) [default]"
    echo "                              api-key   - Anthropic API key"
    echo "                              bedrock   - AWS Bedrock"
    echo "                              vertex    - Google Vertex AI"
    echo ""
    echo "  Auth flags (shortcuts):"
    echo "  --claude, -c                Use Claude app authentication"
    echo "  --api-key, -a               Use Anthropic API key"
    echo "  --bedrock, -b               Use AWS Bedrock"
    echo "  --vertex                    Use Google Vertex AI"
    echo ""
    echo "Volume Mounting (Docker mode only):"
    echo "  -v SOURCE:TARGET[:OPTIONS]  Mount volume (Docker syntax)"
    echo "                              Can be used multiple times"
    echo ""
    echo "Environment Variables:"
    echo "  ANTHROPIC_MODEL             Claude model (default: $DEFAULT_ANTHROPIC_MODEL)"
    echo "  ANTHROPIC_SMALL_FAST_MODEL  Fast model (default: $DEFAULT_ANTHROPIC_SMALL_FAST_MODEL)"
    echo "  AWS_PROFILE_ID              AWS account ID (required for bedrock)"
    echo "  AWS_REGION                  AWS region (default: $DEFAULT_AWS_REGION)"
    echo "  ANTHROPIC_API_KEY           Anthropic API key (required for api-key)"
    echo "  HTTP_PROXY                  HTTP proxy"
    echo "  HTTPS_PROXY                 HTTPS proxy"
    echo "  CLAUDE_YOLO_DOCKER          Set to 'true' to always use Docker mode"
    echo "  CLAUDE_YOLO_TAG             Docker image tag (default: latest)"
    echo "  CLAUDE_UID                  Override container user UID (default: host user UID)"
    echo "  CLAUDE_GID                  Override container user GID (default: host user GID)"
    echo "  CLAUDE_CODE_MAX_OUTPUT_TOKENS  Maximum output tokens limit"
    echo "  CLAUDE_CODE_USE_VERTEX      Use Google Vertex AI"
    echo "  DISABLE_TELEMETRY           Disable Claude Code telemetry"
    echo "  CLAUDE_YOLO_DOCKER_SOCKET   Mount Docker socket (default: false, set to 'true' to enable)"
    echo "  CLAUDE_EXTRA_VOLUMES        Extra volumes to mount in the container"
    echo "  GH_TOKEN                    GitHub CLI authentication token"
    echo "  GITHUB_TOKEN                GitHub CLI authentication token (alternative)"
    echo ""
    echo "Available models: sonnet-4, opus-4, sonnet-3-7, sonnet-3-5, haiku-3-5, sonnet-3, opus-3, haiku-3, deepseek-r1"
    echo ""
    echo "Examples:"
    echo "  $0                                            # Claude app auth (default)"
    echo "  $0 --auth-with api-key                        # Use API key"
    echo "  $0 --auth-with bedrock                        # Use AWS Bedrock"
    echo "  $0 --auth-with vertex                         # Use Google Vertex AI"
    echo "  $0 --yolo                                     # YOLO mode with default auth"
    echo "  $0 --yolo --auth-with bedrock                 # YOLO mode with Bedrock"
    echo "  $0 --yolo -v ~/.ssh:/root/.ssh:ro             # YOLO mode with volume mount"
    echo "  ANTHROPIC_MODEL=opus-4 $0                     # Use Opus 4 with default auth"
    echo "  GH_TOKEN=ghp_xxx $0 --yolo                    # YOLO mode with GitHub CLI auth"
    echo ""
}

check_image() {
    if ! docker image inspect "${DOCKER_IMAGE}:${DOCKER_TAG}" >/dev/null 2>&1; then
        echo "error: Docker image ${DOCKER_IMAGE}:${DOCKER_TAG} not found"
        echo "build it first with: make build"
        echo "or pull it with: docker pull ${DOCKER_IMAGE}:${DOCKER_TAG}"
        exit 1
    fi
}

get_model_arn() {
    local model_alias="$1"
    local model_name=""

    case "$model_alias" in
    "sonnet-4") model_name="us.anthropic.claude-sonnet-4-20250514-v1:0" ;;
    "opus-4") model_name="us.anthropic.claude-opus-4-20250514-v1:0" ;;
    "sonnet-3-7") model_name="us.anthropic.claude-3-7-sonnet-20250219-v1:0" ;;
    "sonnet-3-5" | "sonnet-3-5-v2") model_name="us.anthropic.claude-3-5-sonnet-20241022-v2:0" ;;
    "sonnet-3-5-v1") model_name="us.anthropic.claude-3-5-sonnet-20240620-v1:0" ;;
    "haiku-3-5") model_name="us.anthropic.claude-3-5-haiku-20241022-v1:0" ;;
    "sonnet-3") model_name="us.anthropic.claude-3-sonnet-20240229-v1:0" ;;
    "opus-3") model_name="us.anthropic.claude-3-opus-20240229-v1:0" ;;
    "haiku-3") model_name="us.anthropic.claude-3-haiku-20240307-v1:0" ;;
    "deepseek-r1") model_name="us.deepseek.r1-v1:0" ;;
    *)
        echo "$model_alias"
        return
        ;;
    esac

    echo "arn:aws:bedrock:${AWS_REGION}:${AWS_PROFILE_ID}:inference-profile/${model_name}"
}

USE_TRACE=false
VERBOSE=false
CLAUDE_ARGS=()
OPEN_SHELL=false
AUTH_MODE="claude"
EXTRA_VOLUMES=()

green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
bright_yellow() { echo -e "\033[93m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

i=0
args=("$@")
while [ $i -lt ${#args[@]} ]; do
    arg="${args[$i]}"
    case $arg in
    --help | -h)
        show_help
        exit 0
        ;;
    --version)
        echo "Claude Code YOLO v${VERSION}"
        echo "Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
        exit 0
        ;;
    --trace)
        USE_TRACE=true
        i=$((i + 1))
        ;;
    --verbose)
        VERBOSE=true
        i=$((i + 1))
        ;;
    --yolo)
        USE_DOCKER=true
        i=$((i + 1))
        ;;
    --auth-with)
        if [ $((i + 1)) -lt ${#args[@]} ]; then
            next_arg="${args[$((i + 1))]}"
            case "$next_arg" in
            claude | api-key | bedrock | vertex)
                AUTH_MODE="$next_arg"
                i=$((i + 2))
                ;;
            *)
                echo "error: Invalid auth method: $next_arg" >&2
                echo "Valid methods: claude, api-key, bedrock, vertex" >&2
                exit 1
                ;;
            esac
        else
            echo "error: --auth-with requires an argument" >&2
            exit 1
        fi
        ;;
    --claude | -c)
        AUTH_MODE="claude"
        i=$((i + 1))
        ;;
    --api-key | -a)
        AUTH_MODE="api-key"
        i=$((i + 1))
        ;;
    --bedrock | -b)
        AUTH_MODE="bedrock"
        i=$((i + 1))
        ;;
    --vertex)
        AUTH_MODE="vertex"
        i=$((i + 1))
        ;;
    -v)
        # Volume mounting (only in Docker mode)
        if [ $((i + 1)) -lt ${#args[@]} ]; then
            EXTRA_VOLUMES+=("-v" "${args[$((i + 1))]}")
            i=$((i + 2))
        else
            echo "error: -v requires an argument" >&2
            exit 1
        fi
        ;;
    --shell)
        OPEN_SHELL=true
        USE_DOCKER=true
        i=$((i + 1))
        ;;
    *)
        CLAUDE_ARGS+=("$arg")
        i=$((i + 1))
        ;;
    esac
done

run_claude_local() {
    CLAUDE_PATH="$HOME/.claude/local/node_modules/.bin/claude"
    CLAUDE_TRACE_PATH="claude-trace"

    if [ ! -x "$CLAUDE_PATH" ]; then
        echo "[claude.sh] error: Claude executable not found at: $CLAUDE_PATH" >&2
        echo "[claude.sh] try running 'claude migrate-installer' to migrate claude to local" >&2
        CLAUDE_FALLBACK="$HOME/.claude/local/claude"
        if [ -x "$CLAUDE_FALLBACK" ]; then
            echo "[claude.sh] trying fallback wrapper script: $CLAUDE_FALLBACK" >&2
            CLAUDE_PATH="$CLAUDE_FALLBACK"
        else
            echo "[claude.sh] error: No Claude installation found" >&2
            echo "[claude.sh] install Claude CLI first: https://claude.ai/cli" >&2
            exit 1
        fi
    fi

    case "$AUTH_MODE" in
    "bedrock")
        AUTH_STATUS="$(yellow 'BEDROCK')"
        if [ -z "$AWS_PROFILE_ID" ]; then
            echo "error: AWS_PROFILE_ID not set. Required for --bedrock mode."
            exit 1
        fi
        AWS_REGION="${AWS_REGION:-$DEFAULT_AWS_REGION}"

        ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-$DEFAULT_ANTHROPIC_MODEL}"
        ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-$DEFAULT_ANTHROPIC_SMALL_FAST_MODEL}"

        export ANTHROPIC_MODEL=$(get_model_arn "$ANTHROPIC_MODEL")
        export ANTHROPIC_SMALL_FAST_MODEL=$(get_model_arn "$ANTHROPIC_SMALL_FAST_MODEL")
        export CLAUDE_CODE_USE_BEDROCK=1
        export AWS_REGION="$AWS_REGION"
        export CLAUDE_CODE_MAX_OUTPUT_TOKENS=8192
        ;;
    "api-key")
        AUTH_STATUS="$(yellow 'API-KEY')"
        if [ -z "$ANTHROPIC_API_KEY" ]; then
            echo "error: ANTHROPIC_API_KEY not set. Required for --api-key mode."
            exit 1
        fi
        # For API key mode, use model aliases (convert to actual model names if using aliases)
        ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-$DEFAULT_ANTHROPIC_MODEL}"
        ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-$DEFAULT_ANTHROPIC_SMALL_FAST_MODEL}"

        # Convert aliases to actual model names for API key usage
        case "$ANTHROPIC_MODEL" in
        "sonnet-4") export ANTHROPIC_MODEL="claude-sonnet-4-20250514" ;;
        "opus-4") export ANTHROPIC_MODEL="claude-opus-4-20250514" ;;
        "sonnet-3-7") export ANTHROPIC_MODEL="claude-3-7-sonnet-20250219" ;;
        "sonnet-3-5" | "sonnet-3-5-v2") export ANTHROPIC_MODEL="claude-3-5-sonnet-20241022" ;;
        "sonnet-3-5-v1") export ANTHROPIC_MODEL="claude-3-5-sonnet-20240620" ;;
        "haiku-3-5") export ANTHROPIC_MODEL="claude-3-5-haiku-20241022" ;;
        "sonnet-3") export ANTHROPIC_MODEL="claude-3-sonnet-20240229" ;;
        "opus-3") export ANTHROPIC_MODEL="claude-3-opus-20240229" ;;
        "haiku-3") export ANTHROPIC_MODEL="claude-3-haiku-20240307" ;;
        esac

        case "$ANTHROPIC_SMALL_FAST_MODEL" in
        "sonnet-4") export ANTHROPIC_SMALL_FAST_MODEL="claude-sonnet-4-20250514" ;;
        "opus-4") export ANTHROPIC_SMALL_FAST_MODEL="claude-opus-4-20250514" ;;
        "sonnet-3-7") export ANTHROPIC_SMALL_FAST_MODEL="claude-3-7-sonnet-20250219" ;;
        "sonnet-3-5" | "sonnet-3-5-v2") export ANTHROPIC_SMALL_FAST_MODEL="claude-3-5-sonnet-20241022" ;;
        "sonnet-3-5-v1") export ANTHROPIC_SMALL_FAST_MODEL="claude-3-5-sonnet-20240620" ;;
        "haiku-3-5") export ANTHROPIC_SMALL_FAST_MODEL="claude-3-5-haiku-20241022" ;;
        "sonnet-3") export ANTHROPIC_SMALL_FAST_MODEL="claude-3-sonnet-20240229" ;;
        "opus-3") export ANTHROPIC_SMALL_FAST_MODEL="claude-3-opus-20240229" ;;
        "haiku-3") export ANTHROPIC_SMALL_FAST_MODEL="claude-3-haiku-20240307" ;;
        esac

        echo "Main model: $ANTHROPIC_MODEL"
        echo "Fast model: $ANTHROPIC_SMALL_FAST_MODEL"
        ;;
    "vertex")
        AUTH_STATUS="$(yellow 'VERTEX')"
        export CLAUDE_CODE_USE_VERTEX=1
        export CLAUDE_CODE_MAX_OUTPUT_TOKENS=8192

        ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-$DEFAULT_ANTHROPIC_MODEL}"
        ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-$DEFAULT_ANTHROPIC_SMALL_FAST_MODEL}"
        ;;
    *)
        AUTH_STATUS="$(green 'OAuth')"
        if [ ! -d "$HOME/.claude" ]; then
            echo "[!] $(yellow 'Claude not authenticated') - run 'claude login' first"
        fi
        unset ANTHROPIC_API_KEY
        unset CLAUDE_CODE_USE_BEDROCK
        ;;
    esac

    HEADER_LINE="$(green ">>> CLAUDE-LOCAL v$VERSION") | $AUTH_STATUS"
    [ "$USE_TRACE" = true ] && HEADER_LINE+=" | Trace:$(yellow 'ON')"

    echo ""
    echo "$HEADER_LINE"
    echo "Work: $(blue "$(pwd)")"

    ENV_VARS=""
    [ -n "$ANTHROPIC_MODEL" ] && ENV_VARS+="   $(green 'MODEL'): $ANTHROPIC_MODEL\n"
    [ -n "$HTTP_PROXY" ] && ENV_VARS+="   $(yellow 'PROXY'): $HTTP_PROXY\n"

    if [ -n "$ENV_VARS" ]; then
        echo "Envs:"
        echo -e "$ENV_VARS"
    fi

    local has_dangerous_flag=false
    for arg in "${CLAUDE_ARGS[@]}"; do
        if [[ "$arg" == "--dangerously-skip-permissions" ]]; then
            has_dangerous_flag=true
            break
        fi
    done

    if [ "$has_dangerous_flag" = true ]; then
        echo ""
        echo "$(bright_yellow 'BYPASS MODE - claude-code now gets full access to current workspace without asking for permission')"
    fi

    echo ""
    echo "$(blue '────────────────────────────────────')"
    echo ""

    if [ "$USE_TRACE" = true ]; then
        if command -v "$CLAUDE_TRACE_PATH" >/dev/null 2>&1; then
            CLAUDE_CMD="$CLAUDE_TRACE_PATH"
            FINAL_ARGS=("--include-all-requests" "--run-with" "${CLAUDE_ARGS[@]}")
        else
            echo "error: claude-trace not found but --trace was requested" >&2
            echo "install claude-trace with: npm install -g @mariozechner/claude-trace" >&2
            exit 1
        fi
    else
        CLAUDE_CMD="$CLAUDE_PATH"
        FINAL_ARGS=("${CLAUDE_ARGS[@]}")
    fi
    exec "$CLAUDE_CMD" "${FINAL_ARGS[@]}"
}

check_dangerous_directory() {
    local current_dir="$(pwd)"
    local dangerous_dirs=(
        "$HOME"
        "/"
        "/etc"
        "/usr"
        "/var"
        "/opt"
        "/bin"
        "/sbin"
        "/lib"
        "/lib64"
        "/boot"
        "/dev"
        "/proc"
        "/sys"
        "/tmp"
        "/root"
        "/mnt"
        "/media"
        "/srv"
    )

    for dir in "${dangerous_dirs[@]}"; do
        if [ "$current_dir" = "$dir" ]; then
            return 0
        fi
    done

    if [ "$current_dir" = "/home" ] || [ "$current_dir" = "$(dirname "$HOME")" ]; then
        return 0
    fi

    return 1
}

warn_dangerous_directory() {
    echo "WARNING: Running Claude YOLO in a system directory!"
    echo "Current directory: $(pwd)"
    echo ""
    echo "Claude will have FULL ACCESS to this directory and all subdirectories."
    echo "This includes ability to read, modify, and delete ANY files."
    echo ""
    echo "NEVER run --yolo mode in:"
    echo "  - Your home directory ($HOME)"
    echo "  - System directories (/, /etc, /usr, etc.)"
    echo "  - Any directory containing sensitive data"
    echo ""
    echo "Are you ABSOLUTELY SURE you want to continue? (type 'yes' to proceed)"
    read -r response
    if [ "$response" != "yes" ]; then
        echo "Aborted. Please cd to a project directory first."
        exit 1
    fi
}

if [ "$USE_DOCKER" != true ]; then
    run_claude_local
    exit 0
fi

if check_dangerous_directory; then
    warn_dangerous_directory
fi

check_image

CURRENT_DIR="$(pwd)"
CURRENT_DIR_BASENAME="$(basename "$CURRENT_DIR")"

CONTAINER_NAME="claude-code-yolo-${CURRENT_DIR_BASENAME}-$$"

DOCKER_ARGS=(
    "run"
    "--rm"
    "-it"
    "--name" "$CONTAINER_NAME"
)

DOCKER_ARGS+=(
    # Mount current directory at same path
    "-v" "${CURRENT_DIR}:${CURRENT_DIR}"

    "-e" "WORKDIR=${CURRENT_DIR}"
    "-w" "${CURRENT_DIR}"

)

# Essential mounts for Claude
if [ -d "$HOME/.claude" ]; then
    DOCKER_ARGS+=("-v" "$HOME/.claude:/root/.claude")
fi

if [ -f "$HOME/.claude.json" ]; then
    DOCKER_ARGS+=("-v" "$HOME/.claude.json:/root/.claude.json")
fi

# Mount project-specific Claude settings if they exist
if [ -d "${CURRENT_DIR}/.claude" ]; then
    DOCKER_ARGS+=("-v" "${CURRENT_DIR}/.claude:${CURRENT_DIR}/.claude")
fi

# Mount for AWS bedrock api
if [ -d "$HOME/.aws" ]; then
    DOCKER_ARGS+=("-v" "$HOME/.aws:/root/.aws:ro")
fi

# Users can mount additional configs with -v flag
# Examples: -v ~/.ssh:/root/.ssh:ro -v ~/.gitconfig:/root/.gitconfig:ro

# Only mount Docker socket if explicitly enabled
if [ "${CLAUDE_YOLO_DOCKER_SOCKET:-false}" = "true" ] && [ -S /var/run/docker.sock ]; then
    DOCKER_ARGS+=("-v" "/var/run/docker.sock:/var/run/docker.sock")
fi

if [ ${#EXTRA_VOLUMES[@]} -gt 0 ]; then
    for volume in "${EXTRA_VOLUMES[@]}"; do
        if [ "$volume" != "-v" ]; then
            DOCKER_ARGS+=("-v" "$volume")
        fi
    done
    CLAUDE_EXTRA_VOLUMES="${EXTRA_VOLUMES[*]}"
    DOCKER_ARGS+=("-e" "CLAUDE_EXTRA_VOLUMES=$CLAUDE_EXTRA_VOLUMES")
fi

# Pass proxy environment variables, translating localhost/127.0.0.1 to host.docker.internal
if [ -n "$HTTP_PROXY" ]; then
    HTTP_PROXY_DOCKER=$(echo "$HTTP_PROXY" | sed 's/127\.0\.0\.1/host.docker.internal/g' | sed 's/localhost/host.docker.internal/g')
    DOCKER_ARGS+=("-e" "HTTP_PROXY=$HTTP_PROXY_DOCKER")
fi
if [ -n "$HTTPS_PROXY" ]; then
    HTTPS_PROXY_DOCKER=$(echo "$HTTPS_PROXY" | sed 's/127\.0\.0\.1/host.docker.internal/g' | sed 's/localhost/host.docker.internal/g')
    DOCKER_ARGS+=("-e" "HTTPS_PROXY=$HTTPS_PROXY_DOCKER")
fi
[ -n "$http_proxy" ] && [ -z "$HTTP_PROXY" ] && {
    http_proxy_DOCKER=$(echo "$http_proxy" | sed 's/127\.0\.0\.1/host.docker.internal/g' | sed 's/localhost/host.docker.internal/g')
    DOCKER_ARGS+=("-e" "HTTP_PROXY=$http_proxy_DOCKER")
}
[ -n "$https_proxy" ] && [ -z "$HTTPS_PROXY" ] && {
    https_proxy_DOCKER=$(echo "$https_proxy" | sed 's/127\.0\.0\.1/host.docker.internal/g' | sed 's/localhost/host.docker.internal/g')
    DOCKER_ARGS+=("-e" "HTTPS_PROXY=$https_proxy_DOCKER")
}
[ -n "$NO_PROXY" ] && DOCKER_ARGS+=("-e" "NO_PROXY=$NO_PROXY")
[ -n "$no_proxy" ] && [ -z "$NO_PROXY" ] && DOCKER_ARGS+=("-e" "NO_PROXY=$no_proxy")

DOCKER_ARGS+=("--add-host" "host.docker.internal:host-gateway")

# Pass timezone - auto-detect if not set
if [ -z "$TZ" ]; then
    if [ -f /etc/localtime ] && command -v readlink >/dev/null 2>&1; then
        DETECTED_TZ=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
        [ -n "$DETECTED_TZ" ] && TZ="$DETECTED_TZ"
    elif [ -f /etc/timezone ]; then
        TZ=$(cat /etc/timezone)
    fi
fi
[ -n "$TZ" ] && DOCKER_ARGS+=("-e" "TZ=$TZ")
[ -n "$LANG" ] && DOCKER_ARGS+=("-e" "LANG=$LANG")
[ -n "$LANGUAGE" ] && DOCKER_ARGS+=("-e" "LANGUAGE=$LANGUAGE")
[ -n "$LC_ALL" ] && DOCKER_ARGS+=("-e" "LC_ALL=$LC_ALL")
[ -n "$TERM" ] && DOCKER_ARGS+=("-e" "TERM=$TERM")
[ -n "$EDITOR" ] && DOCKER_ARGS+=("-e" "EDITOR=$EDITOR")
[ -n "$CLAUDE_CODE_MAX_OUTPUT_TOKENS" ] && DOCKER_ARGS+=("-e" "CLAUDE_CODE_MAX_OUTPUT_TOKENS=$CLAUDE_CODE_MAX_OUTPUT_TOKENS")

# Pass Git configuration
[ -n "$GIT_AUTHOR_NAME" ] && DOCKER_ARGS+=("-e" "GIT_AUTHOR_NAME=$GIT_AUTHOR_NAME")
[ -n "$GIT_AUTHOR_EMAIL" ] && DOCKER_ARGS+=("-e" "GIT_AUTHOR_EMAIL=$GIT_AUTHOR_EMAIL")
[ -n "$GIT_COMMITTER_NAME" ] && DOCKER_ARGS+=("-e" "GIT_COMMITTER_NAME=$GIT_COMMITTER_NAME")
[ -n "$GIT_COMMITTER_EMAIL" ] && DOCKER_ARGS+=("-e" "GIT_COMMITTER_EMAIL=$GIT_COMMITTER_EMAIL")

# Pass GitHub CLI authentication
[ -n "$GH_TOKEN" ] && DOCKER_ARGS+=("-e" "GH_TOKEN=$GH_TOKEN")
[ -n "$GITHUB_TOKEN" ] && DOCKER_ARGS+=("-e" "GITHUB_TOKEN=$GITHUB_TOKEN")

# Pass Node.js development variables
[ -n "$NODE_ENV" ] && DOCKER_ARGS+=("-e" "NODE_ENV=$NODE_ENV")
[ -n "$DEBUG" ] && DOCKER_ARGS+=("-e" "DEBUG=$DEBUG")

# Pass Claude Code specific environment variables
[ -n "$CLAUDE_CODE_USE_VERTEX" ] && DOCKER_ARGS+=("-e" "CLAUDE_CODE_USE_VERTEX=$CLAUDE_CODE_USE_VERTEX")
[ -n "$DISABLE_TELEMETRY" ] && DOCKER_ARGS+=("-e" "DISABLE_TELEMETRY=$DISABLE_TELEMETRY")
[ "$VERBOSE" = true ] && DOCKER_ARGS+=("-e" "VERBOSE=true")

# Always run as non-root claude user for security and file ownership
# Default to host user UID/GID for seamless file access
CLAUDE_UID="${CLAUDE_UID:-$(id -u)}"
CLAUDE_GID="${CLAUDE_GID:-$(id -g)}"
DOCKER_ARGS+=("-e" "CLAUDE_UID=$CLAUDE_UID")
DOCKER_ARGS+=("-e" "CLAUDE_GID=$CLAUDE_GID")

case "$AUTH_MODE" in
"bedrock")
    if [ -z "$AWS_PROFILE_ID" ]; then
        echo "error: AWS_PROFILE_ID not set. Required for --bedrock mode."
        exit 1
    fi
    AWS_REGION="${AWS_REGION:-$DEFAULT_AWS_REGION}"

    ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-$DEFAULT_ANTHROPIC_MODEL}"
    ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-$DEFAULT_ANTHROPIC_SMALL_FAST_MODEL}"

    MAIN_MODEL_ARN=$(get_model_arn "$ANTHROPIC_MODEL")
    FAST_MODEL_ARN=$(get_model_arn "$ANTHROPIC_SMALL_FAST_MODEL")

    DOCKER_ARGS+=(
        "-e" "ANTHROPIC_MODEL=$MAIN_MODEL_ARN"
        "-e" "ANTHROPIC_SMALL_FAST_MODEL=$FAST_MODEL_ARN"
        "-e" "CLAUDE_CODE_USE_BEDROCK=1"
        "-e" "AWS_REGION=$AWS_REGION"
        "-e" "CLAUDE_CODE_MAX_OUTPUT_TOKENS=8192"
    )

    [ -n "$AWS_ACCESS_KEY_ID" ] && DOCKER_ARGS+=("-e" "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID")
    [ -n "$AWS_SECRET_ACCESS_KEY" ] && DOCKER_ARGS+=("-e" "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY")
    [ -n "$AWS_SESSION_TOKEN" ] && DOCKER_ARGS+=("-e" "AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN")
    [ -n "$AWS_PROFILE" ] && DOCKER_ARGS+=("-e" "AWS_PROFILE=$AWS_PROFILE")

    ;;
"api-key")
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        echo "error: ANTHROPIC_API_KEY not set. Required for --api-key mode."
        exit 1
    fi

    ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-$DEFAULT_ANTHROPIC_MODEL}"
    ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-$DEFAULT_ANTHROPIC_SMALL_FAST_MODEL}"

    case "$ANTHROPIC_MODEL" in
    "sonnet-4") MAIN_MODEL_NAME="claude-sonnet-4-20250514" ;;
    "opus-4") MAIN_MODEL_NAME="claude-opus-4-20250514" ;;
    "sonnet-3-7") MAIN_MODEL_NAME="claude-3-7-sonnet-20250219" ;;
    "sonnet-3-5" | "sonnet-3-5-v2") MAIN_MODEL_NAME="claude-3-5-sonnet-20241022" ;;
    "sonnet-3-5-v1") MAIN_MODEL_NAME="claude-3-5-sonnet-20240620" ;;
    "haiku-3-5") MAIN_MODEL_NAME="claude-3-5-haiku-20241022" ;;
    "sonnet-3") MAIN_MODEL_NAME="claude-3-sonnet-20240229" ;;
    "opus-3") MAIN_MODEL_NAME="claude-3-opus-20240229" ;;
    "haiku-3") MAIN_MODEL_NAME="claude-3-haiku-20240307" ;;
    *) MAIN_MODEL_NAME="$ANTHROPIC_MODEL" ;;
    esac

    case "$ANTHROPIC_SMALL_FAST_MODEL" in
    "sonnet-4") FAST_MODEL_NAME="claude-sonnet-4-20250514" ;;
    "opus-4") FAST_MODEL_NAME="claude-opus-4-20250514" ;;
    "sonnet-3-7") FAST_MODEL_NAME="claude-3-7-sonnet-20250219" ;;
    "sonnet-3-5" | "sonnet-3-5-v2") FAST_MODEL_NAME="claude-3-5-sonnet-20241022" ;;
    "sonnet-3-5-v1") FAST_MODEL_NAME="claude-3-5-sonnet-20240620" ;;
    "haiku-3-5") FAST_MODEL_NAME="claude-3-5-haiku-20241022" ;;
    "sonnet-3") FAST_MODEL_NAME="claude-3-sonnet-20240229" ;;
    "opus-3") FAST_MODEL_NAME="claude-3-opus-20240229" ;;
    "haiku-3") FAST_MODEL_NAME="claude-3-haiku-20240307" ;;
    *) FAST_MODEL_NAME="$ANTHROPIC_SMALL_FAST_MODEL" ;;
    esac

    DOCKER_ARGS+=("-e" "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
    DOCKER_ARGS+=("-e" "ANTHROPIC_MODEL=$MAIN_MODEL_NAME")
    DOCKER_ARGS+=("-e" "ANTHROPIC_SMALL_FAST_MODEL=$FAST_MODEL_NAME")

    ;;
"vertex")

    ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-$DEFAULT_ANTHROPIC_MODEL}"
    ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-$DEFAULT_ANTHROPIC_SMALL_FAST_MODEL}"

    DOCKER_ARGS+=(
        "-e" "CLAUDE_CODE_USE_VERTEX=1"
        "-e" "CLAUDE_CODE_MAX_OUTPUT_TOKENS=8192"
        "-e" "ANTHROPIC_MODEL=$ANTHROPIC_MODEL"
        "-e" "ANTHROPIC_SMALL_FAST_MODEL=$ANTHROPIC_SMALL_FAST_MODEL"
    )

    [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && DOCKER_ARGS+=("-e" "GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS")
    [ -n "$GOOGLE_CLOUD_PROJECT" ] && DOCKER_ARGS+=("-e" "GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT")
    [ -n "$GOOGLE_CLOUD_REGION" ] && DOCKER_ARGS+=("-e" "GOOGLE_CLOUD_REGION=$GOOGLE_CLOUD_REGION")

    if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        DOCKER_ARGS+=("-v" "$GOOGLE_APPLICATION_CREDENTIALS:$GOOGLE_APPLICATION_CREDENTIALS")
    fi
    if [ -d "$HOME/.config/gcloud" ]; then
        DOCKER_ARGS+=("-v" "$HOME/.config/gcloud:/root/.config/gcloud")
    fi

    ;;
*)
    if [ ! -d "$HOME/.claude" ]; then
        echo "[!] $(yellow 'Claude not authenticated') - run 'claude login' first"
    fi
    [ -n "$ANTHROPIC_MODEL" ] && DOCKER_ARGS+=("-e" "ANTHROPIC_MODEL=$ANTHROPIC_MODEL")
    [ -n "$ANTHROPIC_SMALL_FAST_MODEL" ] && DOCKER_ARGS+=("-e" "ANTHROPIC_SMALL_FAST_MODEL=$ANTHROPIC_SMALL_FAST_MODEL")

    ;;
esac

AUTH_STATUS=""
case "$AUTH_MODE" in
"api-key") AUTH_STATUS="$(yellow 'API-KEY')" ;;
"bedrock") AUTH_STATUS="$(yellow 'BEDROCK')" ;;
"vertex") AUTH_STATUS="$(yellow 'VERTEX')" ;;
*) AUTH_STATUS="$(green 'OAuth')" ;;
esac

HEADER_LINE="$(green ">>> CLAUDE-YOLO v$VERSION") | $AUTH_STATUS"
[ "$USE_TRACE" = true ] && HEADER_LINE+=" | Trace:$(yellow 'ON')"

echo ""
echo "$HEADER_LINE"
echo "Work: $(blue "$CURRENT_DIR")"

echo "Vols: $(blue "${CURRENT_DIR}:${CURRENT_DIR}") $(green '[workspace]')"
[ -d "$HOME/.claude" ] && echo "      $(blue "$HOME/.claude:/root/.claude") $(green '[auth]')"
[ -f "$HOME/.claude.json" ] && echo "      $(blue "$HOME/.claude.json:/root/.claude.json") $(green '[auth]')"
[ -d "${CURRENT_DIR}/.claude" ] && echo "      $(blue "${CURRENT_DIR}/.claude:${CURRENT_DIR}/.claude") $(green '[project]')"
[ -d "$HOME/.aws" ] && echo "      $(blue "$HOME/.aws:/root/.aws:ro") $(green '[aws]')"
[ "${CLAUDE_YOLO_DOCKER_SOCKET:-false}" = "true" ] && [ -S /var/run/docker.sock ] && echo "      $(blue "/var/run/docker.sock:/var/run/docker.sock") $(yellow '[docker]')"

if [ ${#EXTRA_VOLUMES[@]} -gt 0 ]; then
    for volume in "${EXTRA_VOLUMES[@]}"; do
        if [ "$volume" != "-v" ]; then
            echo "      $(blue "$volume") $(yellow '[user]')"
        fi
    done
fi

ENV_VARS=""
case "$AUTH_MODE" in
"bedrock")
    ENV_VARS+="   $(green 'MODEL'): $MAIN_MODEL_ARN\n"
    ENV_VARS+="   $(green 'FAST'): $FAST_MODEL_ARN\n"
    ENV_VARS+="   $(yellow 'REGION'): $AWS_REGION\n"
    ;;
"api-key")
    ENV_VARS+="   $(green 'MODEL'): $MAIN_MODEL_NAME\n"
    ENV_VARS+="   $(green 'FAST'): $FAST_MODEL_NAME\n"
    ;;
"vertex")
    ENV_VARS+="   $(green 'MODEL'): $ANTHROPIC_MODEL\n"
    ENV_VARS+="   $(green 'FAST'): $ANTHROPIC_SMALL_FAST_MODEL\n"
    ;;
esac
[ -n "$HTTP_PROXY" ] && ENV_VARS+="   $(yellow 'PROXY'): $HTTP_PROXY\n"

if [ -n "$ENV_VARS" ]; then
    echo "Envs:"
    echo -e "$ENV_VARS"
fi

echo ""
echo "$(bright_yellow 'BYPASS MODE - claude-code now gets full access to current workspace without asking for permission')"
echo ""
echo "$(blue '────────────────────────────────────')"
echo ""

DOCKER_ARGS+=("${DOCKER_IMAGE}:${DOCKER_TAG}")

if [ "$OPEN_SHELL" = true ]; then
    DOCKER_ARGS+=("/bin/zsh")
elif [ "$USE_TRACE" = true ]; then
    DOCKER_ARGS+=("claude-trace" "--include-all-requests" "--run-with" "${CLAUDE_ARGS[@]}")
else
    DOCKER_ARGS+=("claude" "${CLAUDE_ARGS[@]}")
fi

exec docker "${DOCKER_ARGS[@]}"
