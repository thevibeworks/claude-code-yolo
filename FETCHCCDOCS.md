# fetchccdocs.sh

Downloads Claude Code docs from Anthropic.

Usage:
```
./fetchccdocs.sh [--format md] [--out dir]
```

Default output: references/claude-code-docs/

What it does:
- Fetches sitemap from docs.anthropic.com
- Extracts claude-code URLs (English only)
- Downloads as .md files
- 3 retries per file
- Saves metadata with fetch date and version

Output structure:
```
references/claude-code-docs/
├── .metadata.json
├── overview.md
├── quickstart.md
├── release-notes/
│   └── claude-code.md
└── ...
```

Requires: curl, bash 