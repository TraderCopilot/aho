# Project Agent Instructions (Template)

> Installed by aho-setup to the project root as `AGENTS.md`. Edit this file to fit your project after installation.

## 1. Language

Choose your preferred working language and state it here. The agent will follow this for dialogue, thinking, and documentation.

Default: English. To use another language, replace this section with your own directive.

## 2. Runtime Configuration (after install)

| Type | Path |
|:---|:---|
| Project skills / workflow | `./.agents/` |
| Global skills | `~/.agents/` |

Do not treat projection directories (e.g. `.claude/skills`) as a second source of truth — they are generated from `.agents/`.

## 3. Git

- Use pull requests for review when possible.
- Do not force-push or hard-reset without explicit confirmation.
- Do not batch-delete branches without confirmation.

## 4. Credentials

- Never hardcode API keys, tokens, or passwords.
- Use environment variables or a local `.env` file (gitignored).
- Never commit `.env`, `.ssh/`, or credential files.
