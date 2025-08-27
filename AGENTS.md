# Repository Guidelines

## Project Structure & Module Organization
- Root CLI: `claude.sh` (main wrapper), `claude-yolo` (YOLO alias).
- Container: `Dockerfile`, `Makefile` for build/test tasks.
- CI/CD: `.github/workflows/*` (CI, release, Claude bot).
- Scripts: `scripts/version-check.sh` (version consistency).
- Docs & examples: `README.md`, `CHANGELOG.md`, `workflows/`, `examples/`.
- Config: project `.claude-yolo` and `.claude-yolo.local` (gitignored); user config under `~/.config/claude-yolo/`.

## Build, Test, and Development Commands
- `make build`: Build Docker image (`CLAUDE_CODE_VERSION` overridable).
- `make rebuild|buildx|buildx-multi`: Rebuild (no cache) or multi‑arch.
- `make test`: Smoke tests (CLI help/version, toolchain check).
- `make lint`: Lint `Dockerfile` (hadolint).
- `make version-check`: Ensure `claude.sh`, tags, and `CHANGELOG.md` align.
- Run locally: `./claude.sh --yolo` or `./claude-yolo` in your project dir.

## Coding Style & Naming Conventions
- Language: Bash. Start scripts with `#!/bin/bash` and `set -e` (consider `-u -o pipefail` when safe).
- Security: validate inputs; avoid backticks/eval; reject path traversal; prefer read‑only mounts.
- Naming: scripts `*.sh`; CLI helpers kebab‑case; constants `ALL_CAPS`, vars/functions `snake_case`.
- Output: short, clear; mask secrets (follow `mask_sensitive_value`).

## Testing Guidelines
- Linting: CI runs ShellCheck. Locally run ShellCheck if installed.
- CI: GitHub Actions runs help/version checks and version consistency.
- Local: `make test` before PR; keep tests minimal and behavior‑focused.
- Versioning: update `VERSION` in `claude.sh` and `CHANGELOG.md`; run `scripts/version-check.sh`.

## Commit & Pull Request Guidelines
- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:` (see `git log`).
- PRs: clear description, linked issues, rationale for security‑sensitive changes, `make test` output.
- Docs: update README/CHANGELOG when user‑visible behavior or flags change.
- Releases: use tags (`vX.Y.Z`) and the release workflow; multi‑arch images are pushed from CI.

## Security & Configuration Tips
- Never run YOLO in `$HOME` or system dirs; always `cd` into a project.
- Validate `-v` mounts; avoid `..` traversal; keep secrets read‑only.
- Prefer project config: `.claude-yolo`; sensitive overrides in `.claude-yolo.local`.
- Auth via env when needed: `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `GH_TOKEN`.

