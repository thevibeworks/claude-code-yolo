# Development Logs

## Issue Analysis: 2025-06-22

### [bug-fixed] --trace flag doesn't pass --dangerously-skip-permissions in YOLO mode

**Problem**: `claude-yolo --trace .` fails to add `--dangerously-skip-permissions` to the claude command.

**Root Cause Found**: 
- In `claude.sh:562`, when `--trace` is used, the command was incorrectly constructed as:
  ```bash
  claude-trace --include-all-requests --run-with .
  ```
- **Missing `claude` command**: Should be `claude-trace --include-all-requests --run-with claude .`

**Two-Part Fix Implemented**:

1. **Fixed command construction** in `claude.sh:562`:
   ```bash
   # Before (broken):
   DOCKER_ARGS+=("claude-trace" "--include-all-requests" "--run-with" "${CLAUDE_ARGS[@]}")
   
   # After (fixed):
   DOCKER_ARGS+=("claude-trace" "--include-all-requests" "--run-with" "claude" "${CLAUDE_ARGS[@]}")
   ```

2. **Enhanced argument injection** in `docker-entrypoint.sh`:
   ```bash
   elif [ "$cmd" = "claude-trace" ]; then
       # claude-trace --include-all-requests --run-with claude [args]
       # Inject --dangerously-skip-permissions after "claude"
       while parsing args; do
           if [ "${args[$i]}" = "--run-with" ] && [ "${args[$((i+1))]}" = "claude" ]; then
               new_args+=("--run-with" "claude" "--dangerously-skip-permissions")
           fi
       done
   ```

**Result**: 
- Input: `claude-yolo --trace .`
- Command: `claude-trace --include-all-requests --run-with claude .`
- Executed: `claude-trace --include-all-requests --run-with claude --dangerously-skip-permissions .`

**Status**: ✅ **FIXED** - Two-part fix ensures proper command structure and flag injection

---

### [enhancement] Make dev tool installation more flexible

**Problem**: All dev tools are baked into Dockerfile, requiring full image rebuild for new tools.

**Current State**: 
- Tools installed in Dockerfile:92-117 (gh, delta, claude, claude-trace)
- Static installation makes customization inflexible
- Image size grows with every tool added
- No runtime tool management

**Solution Options**:

#### Option 1: Runtime Package Installation
```bash
# Environment-driven installation in entrypoint
CLAUDE_INSTALL_PACKAGES="gh,terraform,kubectl"
```
Pros: Maximum flexibility, smaller base image
Cons: Slower startup, network dependency, caching complexity

#### Option 2: Tool Manifest System
```yaml
# .claude-tools.yml in project
tools:
  - gh
  - terraform
  - kubectl
```
Pros: Project-specific tools, version control
Cons: Added complexity, manifest management

#### Option 3: Layered Image Approach
```dockerfile
FROM lroolle/claude-code-yolo:base
RUN install-tool gh terraform kubectl
```
Pros: Docker-native, cacheable layers
Cons: Multiple image variants, registry complexity

#### Option 4: Package Manager Integration
```bash
# In entrypoint, detect and install via various PMs
[ -f requirements.txt ] && pip install -r requirements.txt
[ -f package.json ] && npm install -g $(jq -r '.globalDependencies[]' package.json)
```
Pros: Leverages existing ecosystem patterns
Cons: Multiple package manager complexity

**Recommendation**: Start with Option 1 (runtime installation) with intelligent caching.

---

### [enhancement] Inconsistent authentication handling for dev tools

**Problem**: While Claude auth is seamlessly handled via ~/.claude mounting, other dev tools require manual auth setup inside the container.

**Current Auth State**:
- ✅ **Claude**: Auto-mounted via `~/.claude` → `/root/.claude` → `/home/claude/.claude` (symlink)
- ✅ **AWS**: Auto-mounted via `~/.aws` → `/root/.aws` → `/home/claude/.aws` (symlink) 
- ✅ **Google Cloud**: Auto-mounted via `~/.config/gcloud` → `/root/.config/gcloud` → `/home/claude/.config/gcloud` (symlink)
- ❌ **GitHub CLI**: Requires manual `gh auth login` or token pasting into `/home/claude/.config/gh/`
- ❌ **Docker Hub**: No auth mounting for `docker login`
- ❌ **Terraform**: No auth mounting for `.terraform.d/credentials`
- ❌ **NPM**: No auth mounting for `.npmrc`

**Impact**: Inconsistent developer experience - some tools work seamlessly, others require manual setup.

**Solution Options**:

#### Option 1: Expand Auto-Mounting
```bash
# In claude.sh, add more auth directories
[ -d "$HOME/.config/gh" ] && DOCKER_ARGS+=("-v" "$HOME/.config/gh:/root/.config/gh")
[ -f "$HOME/.npmrc" ] && DOCKER_ARGS+=("-v" "$HOME/.npmrc:/root/.npmrc") 
[ -d "$HOME/.docker" ] && DOCKER_ARGS+=("-v" "$HOME/.docker:/root/.docker")
[ -d "$HOME/.terraform.d" ] && DOCKER_ARGS+=("-v" "$HOME/.terraform.d:/root/.terraform.d")
```
**Pros**: Consistent with current approach, minimal complexity
**Cons**: Hard-coded tool list, doesn't scale

#### Option 2: Generic Config Directory Mounting
```bash
# Mount entire config directories
DOCKER_ARGS+=("-v" "$HOME/.config:/root/.config")
DOCKER_ARGS+=("-v" "$HOME/.local:/root/.local")
```
**Pros**: Catches all XDG-compliant tools automatically
**Cons**: Over-broad mounting, potential security concerns

#### Option 3: Selective Config Mounting with Detection
```bash
# Auto-detect and mount known auth files/dirs
AUTH_PATHS=(
    ".config/gh"     # GitHub CLI
    ".docker"        # Docker Hub
    ".terraform.d"   # Terraform
    ".npmrc"         # NPM
    ".pypirc"        # PyPI
    ".cargo"         # Rust Cargo
)
```
**Pros**: Balanced approach, extensible list
**Cons**: Requires maintenance of auth path list

#### Option 4: Environment Variable Auth Pass-through
```bash
# Pass auth tokens as environment variables
[ -n "$GH_TOKEN" ] && DOCKER_ARGS+=("-e" "GH_TOKEN=$GH_TOKEN")
[ -n "$DOCKER_PASSWORD" ] && DOCKER_ARGS+=("-e" "DOCKER_PASSWORD=$DOCKER_PASSWORD")
[ -n "$NPM_TOKEN" ] && DOCKER_ARGS+=("-e" "NPM_TOKEN=$NPM_TOKEN")
```
**Pros**: Secure, doesn't require file system access
**Cons**: Token-based only, doesn't work for OAuth flows

**Recommendation**: Combine Option 3 (selective mounting) with Option 4 (env var pass-through) for comprehensive auth support.

**Files Affected**:
- `claude.sh:354-376` (current auth mounting logic)
- `docker-entrypoint.sh:91-127` (symlink creation for claude user)

---

### [enhancement-resolved] Multiple Claude instances workflow 

**Original Problem**: Users wanted multiple Claude instances in same project without container name conflicts.

**Original Goal Misunderstanding**: We thought users wanted shared containers, but they actually just wanted **multiple simultaneous instances**.

**Simple Solution Implemented**: 
- **Reverted to process-based naming**: `claude-code-yolo-${CURRENT_DIR_BASENAME}-$$`
- **Keep `--rm` for auto-cleanup**: Each instance gets its own container
- **No complexity needed**: Each process gets unique container name via `$$`

**Result**:
```bash
# Terminal 1:
claude-yolo .  # → claude-code-yolo-myproject-12345

# Terminal 2: 
claude-yolo .  # → claude-code-yolo-myproject-67890

# Both run simultaneously, both auto-cleanup
```

**Why This Works Better**:
- ✅ **Simple**: No shared state, no daemon logic, no container reuse
- ✅ **Isolated**: Each Claude instance in its own container
- ✅ **Clean**: Containers auto-remove with `--rm`
- ✅ **Scalable**: Run as many instances as needed

**Key Insight**: Sometimes the simplest solution (unique names per process) is better than complex shared container architecture.

**Status**: ✅ **RESOLVED** - Ultra-simple solution implemented

---

### [enhancement-completed] Container inspection shortcuts

**Problem**: Container inspection workflow was cumbersome - required multiple steps to access running containers.

**Original Workflow Pain Points**:
1. **Manual discovery**: Must run `docker ps` → find container → copy name
2. **Multi-step access**: `docker exec -it <name> /bin/zsh` → `su - claude` to get proper user context

**Solution Implemented**: Added inspection shortcuts to `claude-yolo` wrapper

**Features Added**:
- `claude-yolo --inspect`: Auto-find and enter container as claude user
- `claude-yolo --ps`: List all containers for current project  
- **Smart selection**: Auto-select single container, prompt for multiple
- **Project-aware**: Only shows containers matching current directory pattern

**Implementation Details**:
```bash
# Container discovery by pattern
CONTAINER_PATTERN="claude-code-yolo-${CURRENT_DIR_BASENAME}-"
find_project_containers() {
    docker ps --filter "name=$CONTAINER_PATTERN" --format "{{.Names}}" 2>/dev/null
}

# Smart container selection
if [ $num_containers -eq 1 ]; then
    # Auto-select single container
    exec docker exec -it "$container" gosu claude /bin/zsh
else
    # Prompt user to choose from multiple
    echo "Multiple containers found for this project:"
    # ... interactive selection
fi
```

**User Experience**:

**Before** (painful):
```bash
docker ps                                    # Find container
docker exec -it claude-code-yolo-proj-12345 /bin/zsh  # Enter container  
su - claude                                  # Switch to proper user
```

**After** (one command):
```bash
claude-yolo --inspect                       # Auto-find + auto-su to claude user
```

**Multiple Container Support**:
```bash
claude-yolo --inspect

Multiple containers found for this project:
  1) claude-code-yolo-myproject-12345 (Up 5 minutes)
  2) claude-code-yolo-myproject-67890 (Up 2 minutes) 

Select container to inspect (1-2): 1
Entering container claude-code-yolo-myproject-12345 as claude user...
```

**Files Modified**:
- `claude-yolo`: Enhanced from simple 22-line wrapper to 75-line tool with container management
- Added help system with `claude-yolo --help`

**Status**: ✅ **COMPLETED** - Issue #4 resolved

---

## Current Implementation Summary

### What We've Built

**Issue #1**: ✅ Fixed `--trace` flag not passing `--dangerously-skip-permissions`
- **Solution**: Added explicit `claude-trace` detection in `docker-entrypoint.sh:167,182`
- **Result**: `claude-yolo --trace .` now works correctly in YOLO mode

**Issue #4**: ✅ Added container inspection shortcuts
- **Solution**: Enhanced `claude-yolo` with `--inspect` and `--ps` commands
- **Result**: One-command container access with smart multi-container selection

**Multiple Instances**: ✅ Simplified approach for concurrent Claude instances  
- **Solution**: Reverted to process-based naming `$$` for unique containers
- **Result**: Multiple `claude-yolo .` commands work simultaneously, auto-cleanup

### Current Architecture

**claude.sh** (578 lines):
- Main Docker wrapper with authentication, environment setup, and container creation
- Process-based container naming: `claude-code-yolo-${CURRENT_DIR_BASENAME}-$$`
- Always uses `--rm` for auto-cleanup
- Supports 4 auth modes: Claude app, API key, AWS Bedrock, Google Vertex AI

**docker-entrypoint.sh** (194 lines):
- Container initialization with environment reporting
- Non-root user setup with proper UID/GID alignment
- Authentication symlink creation (`/root/.claude` → `/home/claude/.claude`)
- Fixed pattern matching for Claude commands (including `claude-trace`)

**claude-yolo** (75 lines):
- Enhanced wrapper with container inspection shortcuts
- Smart container discovery and selection
- Simple fallback to `claude.sh --yolo` for normal operations

### Key Design Principles Applied

1. **Simplicity over complexity**: Chose unique container names over shared containers
2. **User experience focus**: One-command access for common operations
3. **Pattern matching**: Project-aware container management
4. **Auto-cleanup**: Containers remove themselves when done
5. **Smart defaults**: Auto-select single containers, prompt for multiple

---

## Technical Details

### File Locations
- Main wrapper: `claude.sh:559` (YOLO trace command)
- Entrypoint logic: `docker-entrypoint.sh:167-169, 181-183` (dangerous permissions logic)
- Tool installation: `Dockerfile:92-117` (static tool setup)

### Key Functions
- `claude.sh` line 557-562: Trace command construction
- `docker-entrypoint.sh` line 156-189: Command execution with permission handling
- `docker-entrypoint.sh` line 11-64: Environment reporting

---

## Next Steps
1. Create GitHub issues for both problems
2. Implement trace flag fix (simple pattern matching)
3. Design runtime tool installation system
4. Consider adding `.claude-tools` config support