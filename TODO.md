# Claude Code YOLO - TODO List

## Release v0.1.0
- [X] Push images and source code
- [X] Docs, `install.sh`

## Next Up (GitHub Actions & CI)
- [ ] **GitHub Actions Pipeline**
  - Add shellcheck linting for all bash scripts
  - Add hadolint for Dockerfile linting
  - Add automated build and multi-arch support (amd64/arm64)
  - Add basic integration tests

## Script Code Quality (After CI)
- [ ] **Refactor claude.sh** (550+ LOC is too much)
  - Split into modules: arg-parse, auth-env, docker-args
  - Extract proxy translation logic into reusable function
  - Extract model alias conversion tables to separate file
  - Add unit tests for argument parsing

## Image Optimization (When Time Permits)
- [ ] **Dockerfile Cleanup**
  - Remove duplicate Oh-My-Zsh installation
  - Clean apt cache in final stage (`rm -rf /var/lib/apt/lists/*`)
  - Fix `make clean` to be less aggressive

## Known Bugs to Track
- [ ] UID/GID alignment between Dockerfile (1001) and claude.sh (host user)
- [ ] Model alias conversion inconsistency in Docker mode
- [ ] Path resolution issues in docker-entrypoint.sh

---

## Completed Recently ✅
- [X] **Fix Non-Root Execution Bug** 🐛
- [X] Fix `--dangerously-skip-permissions` injection for ALL claude invocations (not just `$1 == "claude"`)
- [X] Implement credential symlink strategy instead of copying
- [X] Resolve auth mounting inconsistency (`/root/` vs `/home/claude/`)
- [x] Fix credential sync - Use permission + symlink approach instead of copying
- [x] Fix --dangerously-skip-permissions consistency in non-root mode
- [x] Add Docker socket security control via CLAUDE_YOLO_DOCKER_SOCKET env var
- [x] Gate Docker socket mount behind `CLAUDE_YOLO_DOCKER_SOCKET=true` env var (default: off)
- [x] Make risky mounts opt-in, not default
- [x] `check_dangerous_directory`
