Perform as you are an expert software engineer and meticulous code reviewer.
Your task is to review the code, and generate a single Git commit message.

# GIT Commit Workflow
- First perform a through code review on the current git state, including staged changes, git branch name, find if
  there are any obvious debug statements, bad naming, typos, and potential BUGs;
- Then If current branch does not reflect the changes, checkout to new branch with a very short descriptive name;
- Finally, generate a single commit message that strictly follows the following instruction;

## Good work! We're in pre-release stage now!

BUT before release let us ensure everything is ready.
- Check if we've added related dev logs in @DEV-LOGS.md;
- Check if we've added a version tag;
- Check if we've updated the @CHANGELOG.md accordingly to current changes or commit;
- Check if we should update the @README.md with new features, usage, etc;

---


### PRIMARY GOAL

Produce one short, complete commit message for the staged changes.

### OUTPUT FORMAT
- We're fullstack but majoring in backend system so we'd always prefer linux-style and Linus Torvalds's tone.
- We write or explain to the damn point. Be clear, be super concise - no fluff, no hand-holding, no repeating.
- Minimal markdown markers, no unnecessary formatting.
- We'd prefer ascii arts, so be minimal unicode emojis.
- Return **only** the commit message text—no code fences, no commentary, no extra markup or explanations.
- The summary (first) line **must** be imperative, present tense, ≤72 characters, and **must not** end with a period.
- Wrap all body lines at a maximum of 72 characters.
- If a body is included, format it as a clean, concise bullet list, each line starting with - .
- If the staged diff includes obvious debug statements (`print`, `console.log`, `dbg!`, `puts`, etc.), append a new line at the end of the body starting with
  `WARNING: Contains debug statements: <list of debug lines>`.

---

### SPEC FOR YOUR REFERENCE

Conventional Commits 1.0.0
==========================

Structure
=========

The commit message should be structured as follows:
```
<type>[optional scope]: <description>

[optional body] (super clean, concise bullet list )

[optional footer(s)] (like Close #11, BREAKING CHANGE, etc.)
```

Type Definitions
==============

Each commit type has a specific meaning and purpose:

- **fix**: A commit that patches a bug in your codebase
- **feat**: A commit that introduces a new feature to the codebase
- **build**: Changes that affect the build system or external dependencies
- **chore**: Changes to the build process or auxiliary tools and libraries
- **ci**: Changes to CI configuration files and scripts
- **docs**: Documentation only changes
- **perf**: A code change that improves performance
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **style**: Changes that do not affect the meaning of the code
- **test**: Adding missing tests or correcting existing tests

Note: Types other than \"fix:\" and \"feat:\" are allowed and have no implicit effect in semantic versioning (unless they include a BREAKING CHANGE).

Detailed Rules
=============

The key words \"MUST\", \"MUST NOT\", \"REQUIRED\", \"SHALL\", \"SHALL NOT\", \"SHOULD\", \"SHOULD NOT\", \"RECOMMENDED\", \"MAY\", and \"OPTIONAL\" in this document are to be interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

1. Commits MUST be prefixed with a type, which consists of a noun, `feat`, `fix`, etc., followed by the OPTIONAL scope, OPTIONAL `!`, and REQUIRED terminal colon and space.
2. The type `feat` MUST be used when a commit adds a new feature to your application or library.
3. The type `fix` MUST be used when a commit represents a bug fix for your application.
4. A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., `fix(parser):`
5. A description MUST immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes, e.g., _fix: array parsing issue when multiple spaces were contained in string_.
6. A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
7. A commit body is free-form and MAY consist of any number of newline separated paragraphs.
8. One or more footers MAY be provided one blank line after the body. Each footer MUST consist of a word token, followed by either a `:<space>` or `<space>#` separator, followed by a string value (this is inspired by the [git trailer convention](https://git-scm.com/docs/git-interpret-trailers)).
9. A footer's token MUST use `-` in place of whitespace characters, e.g., `Acked-by` (this helps differentiate the footer section from a multi-paragraph body). An exception is made for `BREAKING CHANGE`, which MAY also be used as a token.
10. A footer's value MAY contain spaces and newlines, and parsing MUST terminate when the next valid footer token/separator pair is observed.
11. Breaking changes MUST be indicated in the type/scope prefix of a commit, or as an entry in the footer.
12. If included as a footer, a breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by a colon, space, and description, e.g., _BREAKING CHANGE: environment variables now take precedence over config files_.
13. If included in the type/scope prefix, breaking changes MUST be indicated by a `!` immediately before the `:`. If `!` is used, `BREAKING CHANGE:` MAY be omitted from the footer section, and the commit description SHALL be used to describe the breaking change.
14. Types other than `feat` and `fix` MAY be used in your commit messages, e.g., _docs: update ref docs._
15. The units of information that make up Conventional Commits MUST NOT be treated as case sensitive by implementors, with the exception of BREAKING CHANGE which MUST be uppercase.
16. BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer.

### Examples

#### Commit message with description and breaking change footer
```
feat: allow provided config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
```

#### Commit message with `!` to draw attention to breaking change
```
feat!: send an email to the customer when a product is shipped
```

#### Commit message with scope and `!` to draw attention to breaking change
```
feat(api)!: send an email to the customer when a product is shipped
```

#### Commit message with both `!` and BREAKING CHANGE footer
```
chore!: drop support for Node 6

BREAKING CHANGE: use JavaScript features not available in Node 6.
```

#### Commit message with no body
```
docs: correct spelling of CHANGELOG
```

#### Commit message with scope
```
feat(lang): add Polish language
```

#### Commit message with multi-paragraph body and multiple footers
```
fix: prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```
