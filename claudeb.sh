#!/bin/bash

# Claude Bedrock Starter Script
# Sets up environment variables for using Claude with AWS Bedrock
DEFAULT_ANTHROPIC_MODEL="sonnet-4"
DEFAULT_ANTHROPIC_SMALL_FAST_MODEL="haiku-3-5"
DEFAULT_AWS_REGION="us-west-2"

if [ -z "$AWS_PROFILE_ID" ]; then
    echo "❌ AWS_PROFILE_ID environment variable is required" >&2
    echo "💡 Set it with: export AWS_PROFILE_ID=your-profile-id" >&2
    exit 1
fi

AWS_REGION="${AWS_REGION:-$DEFAULT_AWS_REGION}"

get_model_name() {
    local alias="$1"
    case "$alias" in
    "sonnet-4") echo "us.anthropic.claude-sonnet-4-20250514-v1:0" ;;
    "opus-4") echo "us.anthropic.claude-opus-4-20250514-v1:0" ;;
    "sonnet-3-7") echo "us.anthropic.claude-3-7-sonnet-20250219-v1:0" ;;
    "sonnet-3-5" | "sonnet-3-5-v2") echo "us.anthropic.claude-3-5-sonnet-20241022-v2:0" ;;
    "sonnet-3-5-v1") echo "us.anthropic.claude-3-5-sonnet-20240620-v1:0" ;;
    "haiku-3-5") echo "us.anthropic.claude-3-5-haiku-20241022-v1:0" ;;
    "sonnet-3") echo "us.anthropic.claude-3-sonnet-20240229-v1:0" ;;
    "opus-3") echo "us.anthropic.claude-3-opus-20240229-v1:0" ;;
    "haiku-3") echo "us.anthropic.claude-3-haiku-20240307-v1:0" ;;
    "deepseek-r1") echo "us.deepseek.r1-v1:0" ;;
    *)
        echo ""
        return 1
        ;;
    esac
}

build_model_arn() {
    local model_alias="$1"
    local model_name=$(get_model_name "$model_alias")

    if [ -z "$model_name" ]; then
        echo "❌ Invalid model alias: $model_alias" >&2
        echo "Available models: sonnet-4, opus-4, sonnet-3-7, sonnet-3-5, haiku-3-5, sonnet-3, opus-3, haiku-3, deepseek-r1" >&2
        return 1
    fi

    echo "arn:aws:bedrock:${AWS_REGION}:${AWS_PROFILE_ID}:inference-profile/${model_name}"
}

show_help() {
    echo "Claude Bedrock Starter Script"
    echo ""
    echo "Usage: ANTHROPIC_MODEL=model ANTHROPIC_SMALL_FAST_MODEL=fast_model claudeb.sh [--trace] [claude-arguments...]"
    echo ""
    echo "Options:"
    echo "  --trace                     Use claude-trace for logging"
    echo "  --help, -h                  Show this help message"
    echo ""
    echo "Required Environment Variables:"
    echo "  AWS_PROFILE_ID              Your AWS account profile ID"
    echo ""
    echo "Optional Environment Variables:"
    echo "  AWS_REGION                  AWS region (default: $DEFAULT_AWS_REGION)"
    echo "  ANTHROPIC_MODEL             Main model alias (default: $DEFAULT_ANTHROPIC_MODEL)"
    echo "  ANTHROPIC_SMALL_FAST_MODEL  Fast model alias (default: $DEFAULT_ANTHROPIC_SMALL_FAST_MODEL)"
    echo "  HTTP_PROXY                  Set HTTP proxy (optional)"
    echo "  HTTPS_PROXY                 Set HTTPS proxy (optional)"
    echo ""
    echo "Available model aliases: sonnet-4, opus-4, sonnet-3-7, sonnet-3-5, haiku-3-5, sonnet-3, opus-3, haiku-3, deepseek-r1"
    echo "Legacy aliases: sonnet, opus, haiku, fast, balanced, expensive"
    echo ""
    echo "Examples:"
    echo "  export AWS_PROFILE_ID=123456789012"
    echo "  claudeb.sh                                                   # Use defaults"
    echo "  claudeb.sh --trace chat                                      # Use claude-trace"
    echo "  ANTHROPIC_MODEL=opus-4 claudeb.sh .                          # Use Opus 4"
    echo "  ANTHROPIC_MODEL=opus-4 ANTHROPIC_SMALL_FAST_MODEL=sonnet-4 claudeb.sh ."
    echo "  ANTHROPIC_MODEL=deepseek-r1 claudeb.sh --trace .             # Use DeepSeek R1"
    echo "  HTTPS_PROXY=https://proxy.example.com:8080 claudeb.sh        # Use HTTPS proxy"
    echo "  HTTP_PROXY=http://proxy.example.com:8080 claudeb.sh          # Use HTTP proxy"
    echo ""
}

USE_TRACE=false
CLAUDE_ARGS=()

for arg in "$@"; do
    case $arg in
    --help | -h)
        show_help
        exit 0
        ;;
    --trace)
        USE_TRACE=true
        ;;
    *)
        CLAUDE_ARGS+=("$arg")
        ;;
    esac
done

ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-$DEFAULT_ANTHROPIC_MODEL}"
ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-$DEFAULT_ANTHROPIC_SMALL_FAST_MODEL}"
MAIN_MODEL_ARN=$(build_model_arn "$ANTHROPIC_MODEL")
if [ $? -ne 0 ]; then
    exit 1
fi

FAST_MODEL_ARN=$(build_model_arn "$ANTHROPIC_SMALL_FAST_MODEL")
if [ $? -ne 0 ]; then
    exit 1
fi

MAIN_MODEL_NAME=$(get_model_name "$ANTHROPIC_MODEL")
FAST_MODEL_NAME=$(get_model_name "$ANTHROPIC_SMALL_FAST_MODEL")

echo "🤖 Main model: $ANTHROPIC_MODEL ($MAIN_MODEL_NAME)"
echo "⚡ Fast model: $ANTHROPIC_SMALL_FAST_MODEL ($FAST_MODEL_NAME)"
echo "🌍 AWS Region: $AWS_REGION"

CLAUDE_PATH="$HOME/.claude/local/node_modules/.bin/claude"
CLAUDE_TRACE_PATH="claude-trace"
if [ ! -x "$CLAUDE_PATH" ]; then
    echo "❌ Claude executable not found or not executable: $CLAUDE_PATH" >&2
    CLAUDE_FALLBACK="$HOME/.claude/local/claude"
    if [ -x "$CLAUDE_FALLBACK" ]; then
        echo "🔄 Trying fallback wrapper script: $CLAUDE_FALLBACK" >&2
        CLAUDE_PATH="$CLAUDE_FALLBACK"
    else
        exit 1
    fi
fi

export CLAUDE_PATH="$CLAUDE_PATH"
CLAUDE_DIR="$(dirname "$CLAUDE_PATH")"
export PATH="$CLAUDE_DIR:$PATH"
export claude="$CLAUDE_PATH"

if [ "$USE_TRACE" = true ] || command -v "$CLAUDE_TRACE_PATH" >/dev/null 2>&1; then
    if command -v "$CLAUDE_TRACE_PATH" >/dev/null 2>&1; then
        echo "🔍 Using claude-trace for logging interactions"
        CLAUDE_CMD="$CLAUDE_TRACE_PATH"
        FINAL_ARGS=("--include-all-requests" "--run-with" "${CLAUDE_ARGS[@]}")
    else
        if [ "$USE_TRACE" = true ]; then
            echo "❌ claude-trace not found but --trace was requested" >&2
            echo "💡 Install claude-trace with: npm install -g @mariozechner/claude-trace" >&2
            exit 1
        else
            echo "⚠️  claude-trace not found, falling back to direct claude execution"
            echo "💡 Install claude-trace with: npm install -g @mariozechner/claude-trace"
            CLAUDE_CMD="$CLAUDE_PATH"
            FINAL_ARGS=("${CLAUDE_ARGS[@]}")
        fi
    fi
else
    echo "📋 Using direct claude execution"
    CLAUDE_CMD="$CLAUDE_PATH"
    FINAL_ARGS=("${CLAUDE_ARGS[@]}")
fi

export ANTHROPIC_MODEL="$MAIN_MODEL_ARN"
export ANTHROPIC_SMALL_FAST_MODEL="$FAST_MODEL_ARN"
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION="$AWS_REGION"
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=8192

# Show proxy configuration if set
if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
    echo "🌐 Proxy configuration:"
    [ -n "$HTTP_PROXY" ] && echo "  HTTP_PROXY: $HTTP_PROXY"
    [ -n "$HTTPS_PROXY" ] && echo "  HTTPS_PROXY: $HTTPS_PROXY"
else
    echo "🌐 No proxy configured"
fi

# Show which command will be executed
echo "🚀 Starting Claude with command: $CLAUDE_CMD"
if [ "$CLAUDE_CMD" = "$CLAUDE_TRACE_PATH" ]; then
    echo "📝 Logs will be saved to .claude-trace/ in current directory"
    echo "🔧 Claude available in PATH: $(which claude 2>/dev/null || echo 'Not found')"
    echo "📋 Final arguments: ${FINAL_ARGS[*]}"
fi

# Start Claude with explicit proxy settings if configured
if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
    # Explicitly pass proxy environment variables to ensure they're used
    env HTTP_PROXY="$HTTP_PROXY" HTTPS_PROXY="$HTTPS_PROXY" "$CLAUDE_CMD" "${FINAL_ARGS[@]}"
else
    # No proxy configured, run normally
    "$CLAUDE_CMD" "${FINAL_ARGS[@]}"
fi
