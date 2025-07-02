#!/bin/bash
set -e

# Claude Code YOLO Version Consistency Checker
# Validates that all version references are consistent

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

get_claude_version() {
    grep 'VERSION=' claude.sh | head -1 | sed 's/.*VERSION="\([^"]*\)".*/\1/'
}

get_changelog_version() {
    grep -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | sed 's/.*\[\([^]]*\)\].*/\1/'
}

get_git_latest_tag() {
    git tag --list --sort=-version:refname | head -1 | sed 's/^v//'
}

check_consistency() {
    local claude_version=$(get_claude_version)
    local changelog_version=$(get_changelog_version)
    local git_version=$(get_git_latest_tag)
    
    echo "Version Consistency Check"
    echo "========================="
    echo "claude.sh:      $claude_version"
    echo "CHANGELOG.md:   $changelog_version"
    echo "Latest git tag: $git_version"
    echo ""
    
    local issues=0
    
    if [[ "$claude_version" != "$changelog_version" ]]; then
        error "Version mismatch: claude.sh ($claude_version) != CHANGELOG.md ($changelog_version)"
        issues=$((issues + 1))
    else
        success "claude.sh and CHANGELOG.md versions match"
    fi
    
    if [[ "$claude_version" != "$git_version" ]]; then
        if [[ "$claude_version" > "$git_version" ]]; then
            warning "claude.sh version ($claude_version) is newer than latest tag ($git_version) - this is expected for unreleased versions"
        else
            error "claude.sh version ($claude_version) is older than latest tag ($git_version)"
            issues=$((issues + 1))
        fi
    else
        success "claude.sh version matches latest git tag"
    fi
    
    echo ""
    
    if [[ $issues -eq 0 ]]; then
        success "All versions are consistent!"
        return 0
    else
        error "Found $issues version consistency issue(s)"
        echo ""
        echo "To fix:"
        echo "  1. Use ./scripts/release.sh <version> for new releases"
        echo "  2. Or manually update claude.sh and CHANGELOG.md to match"
        return 1
    fi
}

main() {
    if [[ ! -f "claude.sh" ]] || [[ ! -f "CHANGELOG.md" ]]; then
        error "Must be run from claude-code-yolo root directory"
        exit 1
    fi
    
    check_consistency
}

main "$@"