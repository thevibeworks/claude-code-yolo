# RELEASE.md

Release workflow for Claude Code to execute when user runs `make release-patch|minor|major`.

## Release Steps

When user runs release command, Claude Code should:

1. **Check prerequisites**: 
   - Clean working directory
   - On main/master branch
   - Upstream synced (`git fetch && git status`)
   - CI passing (if applicable)

2. **Detect current version**: From claude.sh VERSION variable (canonical source)

3. **Calculate new version**: Increment based on patch/minor/major semantic versioning

4. **Generate changelog**: 
   - Use `git log --oneline --no-merges v<last>..HEAD`
   - Group by commit prefixes: feat/fix/chore/docs
   - Follow CLAUDE.md style (concise, minimal markdown)

5. **Update files**: 
   - Update VERSION in claude.sh
   - Add changelog entry to CHANGELOG.md with date
   - Update version in any other files (Makefile, package.json if exists)

6. **Create commit**: Generate commit message following workflows/GIT-COMMIT.md conventions

7. **Tag and push**: Create git tag, push both commit and tag automatically

8. **Verify**: Show git log and tag info for confirmation

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

## Execution Commands

```bash
# Auto-executed by Claude Code:
git add claude.sh CHANGELOG.md
git commit -m "chore: release v<version>"
git tag -a "v<version>" -m "Release v<version>"
git push origin $(git branch --show-current) --tags
```

## Rollback Strategy

If release fails:
```bash
# Undo last commit (if not pushed)
git reset --hard HEAD~1

# Delete local tag
git tag -d v<version>

# Delete remote tag (if pushed)
git push origin :refs/tags/v<version>
```