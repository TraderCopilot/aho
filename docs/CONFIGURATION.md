# Configuration

This document describes what you can safely configure after a `demo` install, and what is installer-managed and should not be hand-edited.

## 1. The `demo` profile

The public demo release ships exactly one profile: `demo`. It installs the `demo-core` pack, which contains four skills:

| Skill | Purpose |
|:---|:---|
| `thinking-language` | Pins the agent's thinking/output language. |
| `session-boot-ritual` | Session startup checklist. |
| `aho-installer` | SOP for the installer CLI itself. |
| `demo-hello` | Minimal smoke-test skill. |

You cannot pass `--profile standard`, `--profile full-dev`, `--profile minimal`, or any other name — the CLI exits with a clear error. This is intentional: those profiles depend on internal seeds that are not shipped.

## 2. Directory layout after install

```text
<target>/
  .agents/                         ← Source of truth (edit here)
    settings.json
    skills/
      thinking-language/SKILL.md
      session-boot-ritual/SKILL.md
      aho-installer/SKILL.md
      demo-hello/SKILL.md
  .claude/skills/                  ← Projection (do not edit)
  .opencode/skills/                ← Projection (do not edit)
  .codeartsdoer/skills/            ← Projection (do not edit)
  ... (other platform projections)
  AGENTS.md                        ← Project instructions (edit after install)
  CLAUDE.md                        ← Claude-specific instructions
  GEMINI.md                        ← Gemini-specific instructions
  .mcp.json                        ← MCP server config (edit, but never commit secrets)
```

### Edit vs. do-not-edit

| Path | Edit? | Why |
|:---|:---|:---|
| `.agents/skills/*/SKILL.md` | Yes | This is the source of truth. |
| `.agents/settings.json` | Yes | Project-level settings template. |
| `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | Yes | Agent instructions; the installer writes a template you can refine. |
| `.mcp.json` | Yes | Add MCP servers — but use environment variables for secrets, never literal tokens. |
| `.claude/skills/`, `.opencode/skills/`, etc. | **No** | Projections. Regenerated from `.agents/` by `install`. |
| `.claude/settings.json`, `.opencode/config.json` | **No** | Merged by the installer. Hand edits will be overwritten on re-install. |
| `.claude/settings.local.json` | n/a | The installer never writes this. Put local secrets here (gitignored). |

## 3. Settings

### Project settings: `.agents/settings.json`

The shipped template is minimal:

```json
{
  "aho": {
    "schema_version": "1",
    "scope": "project",
    "note": "项目级 .agents 设置模板"
  }
}
```

You may add project-specific keys under `aho`. The installer does not overwrite this file on re-install if you have modified it — it merges.

### Platform settings (do not hand-edit)

The installer writes platform-specific settings (e.g. `.claude/settings.json`, `.opencode/config.json`) by deep-merging from `.agents/settings.json` and the platform's own schema. To change platform behavior, edit `.agents/settings.json` and re-run `install`.

### Local secrets: `.claude/settings.local.json` (or equivalent)

The installer **never** writes this file. It is the correct place for machine-local secrets. Add it to your project `.gitignore`:

```text
*.local.json
.env
```

## 4. MCP servers: `.mcp.json`

The shipped template is empty:

```json
{
  "mcpServers": {}
}
```

To add an MCP server, use **environment variable references**, never literal tokens:

```json
{
  "mcpServers": {
    "example": {
      "command": "npx",
      "args": ["-y", "@example/mcp-server"],
      "env": {
        "API_KEY": "${EXAMPLE_API_KEY}"
      }
    }
  }
}
```

Then set `EXAMPLE_API_KEY` in your shell environment or a local `.env` file (gitignored). Never put the literal key in `.mcp.json`.

## 5. Target directory

`--target` accepts any writable path. The installer:

- Resolves it to an absolute path.
- Refuses filesystem roots (`C:\`, `/`).
- Creates the directory if it does not exist (only with `--apply --confirmed`).
- Does not delete or overwrite the target on re-install; it merges.

To install into the current directory:

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 install --profile demo --target . --apply --confirmed
```

## 6. Global configuration

`global-setup` installs the global skill source at `~/.agents` (or `--home <path>`). It:

- Creates `~/.agents/skills/` with the four demo skills.
- Merges (does not overwrite) existing global instruction files (`~/.agents/AGENTS.md`, etc.).
- Projections into `~/.claude/skills/`, `~/.opencode/skills/`, etc. are junctions on Windows, copies on Linux/macOS.

To use an isolated home for testing:

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 global-setup --home .\test-home --apply --confirmed
```

## 7. Language

Two ways to set the CLI output language:

```powershell
# Per-command
.\apps\aho-setup\bin\aho-setup.ps1 --help --lang zh-CN

# Session-wide
$env:AHO_LANG = "zh-CN"
```

Supported codes: `en-US`, `zh-CN`. If unset, the CLI follows the UI culture.

## 8. Re-install and idempotency

Re-running `install` with the same arguments is safe:

- Skills are re-projected (content updated to match `.agents/`).
- Settings are deep-merged.
- Existing user edits in `.agents/` and `AGENTS.md` are preserved.

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 install --profile demo --target .\my-project --apply --confirmed
```

## 9. What you cannot configure in this release

- **Custom profiles** — not supported in the public demo. Use the private development repository to define new profiles.
- **Additional packs** — only `demo-core` is shipped.
- **Internal commands** — `reseed`, `skill add`, `matt-setup` are disabled and hidden from help.
- **Platform hooks** — A-grade platforms receive hooks; B-grade platforms do not. You cannot upgrade a B-grade platform by configuration alone.

## 10. Verification after configuration changes

After editing `.agents/` or `.mcp.json`:

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 verify --target .\my-project
.\apps\aho-setup\bin\aho-setup.ps1 doctor --target .\my-project
```

Both should exit 0. If not, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
