# Development Logs
- Prepend new entries with `## Issue Analysis: YYYY-MM-DD`.
- We write or explain to the damn point. Be clear, be super concise - no fluff, no hand-holding, no repeating.
- Minimal markdown markers, no unnecessary formatting, minimal unicode emojis.

## Issue Analysis: 2025-06-22

### [bug-critical] Argument parsing infinite loop in claude-yolo

**Problem**: Cursor bot detected critical bugs in claude-yolo argument parsing.

**Root Cause Analysis**:

**Bug 1 - Infinite Loop**: Lines 84-89 in parse_args() missing `shift` statements:
```bash
--inspect)
    inspect_container  # ❌ Missing shift - infinite loop
;;
--ps)
    list_containers   # ❌ Missing shift - infinite loop
;;
```

**Bug 2 - Duplicate Handling**: Lines 122-137 duplicate parse_args() logic:
```bash
# Main script also handles --inspect/--ps directly
case "$1" in
--inspect) inspect_container ;;  # ❌ Duplicate of parse_args
--ps) list_containers ;;         # ❌ Duplicate + no exit
```

**Impact**:
- Infinite loop when using `--inspect` or `--ps`
- `--ps` shows containers but continues to exec claude.sh
- Mixed options like `claude-yolo --inspect -v ~/foo:/bar` silently ignore -v
- Inconsistent behavior between direct calls and mixed arguments

**Technical Details**:
- **Flow Issue**: parse_args() calls inspect_container() → exits, but missing shift causes loop
- **Design Flaw**: Two separate parsing paths with different behaviors
- **Silent Failures**: Some argument combinations work, others don't

**Status**: Critical - requires immediate fix

---

## Issue Analysis: 2025-06-22

### [problem-discovered] GitHub CLI auth fails in containers

**Problem**: Mounting `~/.config/gh/` doesn't work for GitHub CLI authentication in containers.

**Root Cause**: Modern `gh` uses secure keyring storage instead of plain text files:
- **Host**: Tokens stored in macOS Keychain/Linux Secret Service/Windows Credential Manager
- **Container**: No keyring access, auth fails even with mounted config directory
- **Split State**: Config files present but tokens inaccessible

**Technical Details**:
```bash
# Host auth state:
~/.config/gh/config.yml     # Configuration
~/.config/gh/hosts.yml      # May contain tokens OR keyring references
System Keyring              # Actual tokens (secure storage)

# Container reality:
/root/.config/gh/config.yml # ✅ Mounted successfully
/root/.config/gh/hosts.yml  # ✅ Mounted but may reference unavailable keyring
No System Keyring          # ❌ DBus/keyring services not available
```

**Why This Matters**: Current codebase has complete auth system for Claude/AWS/GCloud but GitHub CLI missing.

**Immediate Impact**: Cannot create PRs or manage GitHub repos from within containers.

**Solutions Research**:
1. **Environment Variable**: `GH_TOKEN="ghp_xxx"` - simple, headless-friendly
2. **Insecure Storage**: `gh auth login --insecure-storage` on host, then mount works
3. **Token Injection**: `echo $TOKEN | gh auth login --with-token` in container
4. **Mount Strategy**: Add explicit GitHub CLI auth mounting to claude.sh

**Status**: Research complete, need implementation decision.

---

## Issue Analysis: 2025-06-22

### [enhancement] Controlled auth directory mounting

**Problem**: Symlinking all /root/* was too broad and risky.

**Better approach**: Explicit, controlled mounts with proper permissions:
```bash
# claude.sh mounts:
~/.claude → /root/.claude          # read-write (auth tokens)
~/.config → /root/.config:ro       # read-only (XDG tools)
~/.aws → /root/.aws:ro            # read-only
~/.ssh → /root/.ssh:ro            # read-only
~/.gitconfig → /root/.gitconfig:ro # read-only

# docker-entrypoint.sh:
- Symlinks specific directories to /home/claude
- Sets XDG_CONFIG_HOME=/root/.config
- Maintains controlled access list
```

**Benefits**:
- ✅ Security: Read-only where appropriate
- ✅ XDG compliance: Entire .config dir for gh/gcloud/etc
- ✅ Explicit: Clear what's accessible
- ✅ Safe: No unexpected file exposure

**Status**: -> **IMPLEMENTED**

### [enhancement-implemented] Consolidate auth options to --auth-with pattern

**Problem**: Auth flags conflict with common conventions (-v for volumes vs Vertex).

**Current mess**:
- `-c/--claude` → Claude app (OAuth)
- `-a/--api-key` → Anthropic API
- `-b/--bedrock` → AWS Bedrock
- `-v/--vertex` → Google Vertex AI (blocks -v for volumes!)

**Solution**: Single `--auth-with` parameter:
```bash
claude.sh --auth-with vertex .     # Explicit auth method
claude.sh -v ~/.ssh:/root/.ssh .   # -v now free for volumes
```

**Implementation**:
1. ✅ Added `--auth-with METHOD` parsing in claude.sh
2. ✅ Kept old flags for backward compatibility (with deprecation warnings)
3. ✅ Freed up `-v` for volume mounting (Docker convention)
4. ✅ Updated claude-yolo to use `-v` instead of `--mount`

**Benefits**:
- ✅ Follows Docker convention (-v for volumes)
- ✅ Cleaner, extensible auth interface
- ✅ No more flag conflicts
- ✅ Better CLI UX

**Status**: ✅ **IMPLEMENTED**

### [enhancement-implemented] Generalized config mounting

**Problem**: Hardcoding each tool's config mount doesn't scale.

**Root cause**: Mount to /root, run as claude user -> symlink hell.

**Initial Proposal**: Mount entire ~/.config, use XDG standards.

**Implemented Solution**: Added flexible volume mounting via `-v` argument in claude-yolo.

```bash
# New usage - users can mount any config they need:
claude-yolo -v ~/.gitconfig:/root/.gitconfig .
claude-yolo -v ~/.ssh:/root/.ssh:ro .
claude-yolo -v ~/tools:/tools -v ~/data:/data .

# Implementation in claude-yolo:
- Parse -v/--mount arguments, collect in array
- Pass to claude.sh via CLAUDE_EXTRA_VOLUMES env var
- claude.sh adds these volumes to Docker run command
```

**Benefits**:
- ✅ **Flexible**: Mount any config/directory as needed
- ✅ **Familiar**: Uses Docker's -v syntax
- ✅ **Secure**: Users control what to expose
- ✅ **Extensible**: No hardcoded tool list to maintain

**Result**: Zero maintenance. New tools work via explicit mounting.

**Status**: ✅ **IMPLEMENTED** - Added -v/--mount support to claude-yolo

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
   claude-trace --include-all-requests --run-with claude .
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
