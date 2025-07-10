# Claude Code YOLO - TODO List

## High Priority
- [ ] Issue #1: Fix --trace not passing --dangerously-skip-permissions
- [ ] Issue #4: Add container shortcuts to claude-yolo 
- [ ] Issue #3: Consistent auth mounting for dev tools
- [ ] Issue #2: Flexible dev tool installation

## Medium Priority
- [ ] Refactor claude.sh (570+ LOC)
- [ ] GitHub Actions CI/CD pipeline
- [ ] Dockerfile cleanup

---

## Completed Recently ✅
- [X] **Fix Non-Root Execution Bug** 🐛
- [X] Fix `--dangerously-skip-permissions` injection for ALL claude invocations (not just `$1 == "claude"`)
- [X] Implement credential symlink strategy instead of copying
- [X] Resolve auth mounting inconsistency (`/root/` vs `/home/claude/`)
- [x] Fix credential sync - Use permission + symlink approach instead of copying
- [x] Fix --dangerously-skip-permissions consistency in non-root mode
- [x] Add Docker socket security control via CCYOLO_DOCKER_SOCKET env var
- [x] Gate Docker socket mount behind `CCYOLO_DOCKER_SOCKET=true` env var (default: off)
- [x] Make risky mounts opt-in, not default
- [x] `check_dangerous_directory`
