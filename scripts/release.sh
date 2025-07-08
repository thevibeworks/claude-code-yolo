#!/bin/bash
set -e

# Simple release script - delegates to Claude Code for intelligent work

usage() {
    echo "Usage: $0 <patch|minor|major>"
    echo "This script delegates release workflow to Claude Code."
    echo "See workflows/RELEASE.md for details."
}

check_prerequisites() {
    if ! git diff --quiet HEAD; then
        echo "Error: Working directory has uncommitted changes. Please commit or stash them first." >&2
        exit 1
    fi

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CLAUDE_YOLO="$SCRIPT_DIR/../claude-yolo"
    
    if [ ! -x "$CLAUDE_YOLO" ]; then
        echo "Error: claude-yolo not found or not executable at $CLAUDE_YOLO" >&2
        exit 1
    fi
}

main() {
    if [[ $# -ne 1 ]] || [[ ! "$1" =~ ^(patch|minor|major)$ ]]; then
        usage
        exit 1
    fi

    local release_type="$1"
    
    echo "🚀 Starting $release_type release..."
    echo "Delegating to Claude Code - see workflows/RELEASE.md"
    echo ""
    
    check_prerequisites
    
    # Let Claude Code handle the intelligent workflow with auto-proceed
    "$CLAUDE_YOLO" -p "Execute the release workflow from workflows/RELEASE.md for a **$release_type** release. 

Release type: $release_type
Current working directory: $(pwd)

Follow all the steps exactly as documented in workflows/RELEASE.md."
}

main "$@"
