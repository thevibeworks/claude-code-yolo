# RELEASE.md

Release workflow for Claude Code to execute when user runs `make release-patch|minor|major`.

## Release Steps

When user runs release command, Claude Code should:

1. **Check prerequisites**: Ensure clean working directory
2. **Detect current version**: From git tags (`git describe --tags --abbrev=0`) or claude.sh VERSION
3. **Calculate new version**: Increment based on patch/minor/major semantic versioning
4. **Generate changelog**: Use git log since last version, follow CLAUDE.md style (concise, minimal markdown)
5. **Update files**: Update VERSION in claude.sh, add changelog entry to CHANGELOG.md
6. **Create commit**: Generate commit message following workflows/GIT-COMMIT.md conventions
7. **Tag and push**: Create git tag, show push commands

## Versioning Rules

- **patch** (x.y.Z): Bug fixes, small improvements
- **minor** (x.Y.0): New features, backwards compatible
- **major** (X.0.0): Breaking changes

## Changelog Style

Follow CLAUDE.md guidelines:
- Concise, no fluff
- Minimal markdown formatting
- Group by Added/Fixed/Changed
- Remove empty sections

## Commit Message Style

Follow workflows/GIT-COMMIT.md:
- Format: `chore: release vX.Y.Z`
- Include version update details in body
- Use imperative mood

## Post-Release Commands

```bash
git push origin $(git branch --show-current) --tags
gh pr create --title "chore: release v<version>" --body "Release version <version>"
```