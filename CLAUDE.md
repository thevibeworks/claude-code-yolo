# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## We're following Issue-Based Development (IBD) workflow
1. Before running any Git/GitHub CLI `Bash` command (`git commit`, `gh issue create`, `gh pr create`, etc.), open the corresponding file in @workflows to review required steps.
2. Always apply the exact templates or conventions from the following files:
   - @workflows/GITHUB-ISSUE.md → issues
   - @workflows/GIT-COMMIT.md  → commits
   - @workflows/GITHUB-PR.md   → pull requests
   - @workflows/RELEASE.md     → releases
3. Keep one branch per issue; merging the PR must auto-close its linked issue.


@./AGENTS.md
