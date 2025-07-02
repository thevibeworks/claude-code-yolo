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
    
    if ! command -v claude >/dev/null 2>&1; then
        echo "Error: Claude CLI not found. Please install Claude Code." >&2
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
    
    # Let Claude Code handle the intelligent workflow
    claude "Execute the release workflow from workflows/RELEASE.md for a $release_type release. Follow all the steps exactly as documented."
}

main "$@"
