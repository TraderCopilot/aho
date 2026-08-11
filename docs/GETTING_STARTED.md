# Getting Started

This guide takes a new user from a clean machine to a verified `demo` install in one pass. No internal knowledge, private templates, or prior configuration is assumed.

## 1. Prerequisites

| Requirement | Check command | Install if missing |
|:---|:---|:---|
| Windows PowerShell 5.1 or PowerShell 7 | `$PSVersionTable.PSVersion.Major -ge 5` | PowerShell 7 is recommended: <https://github.com/PowerShell/PowerShell> |
| Git | `git --version` | <https://git-scm.com> |
| Write access to a target project directory | `Test-Path .\my-project` | `New-Item -ItemType Directory .\my-project` |

On Linux / macOS, install PowerShell 7 (`pwsh`) and use it in place of `powershell` throughout this guide. Junctions degrade to copies — see [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md).

## 2. Get the release tree

Clone this repository (or download and extract the release archive) to a local path:

```powershell
git clone <this-repo-url> aho-demo
cd aho-demo
```

Confirm the entry script is present:

```powershell
Test-Path .\apps\aho-setup\bin\aho-setup.ps1
# True
```

## 3. Read the help (read-only)

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 --help
```

Expected output (abridged):

```text
aho-setup -- agents-harness-os (aho) installer

Commands:
  discover       --target <path>
  plan           --profile <name> --target <path>
  install        --profile <name> --target <path> [--apply] [--confirmed]
  verify         --target <path>
  global-plan    [--home <path>]
  global-setup   [--home <path>] [--apply] [--confirmed]
  doctor         --target <path>
  scan           --target <path>

  Allowed profiles: demo. Default: demo

Notes:
  - Default is dry-run for write commands; --apply --confirmed required to materialize.
```

If `Allowed profiles: demo` is missing, you are not running the public demo release — stop and re-clone.

## 4. Preview the install plan (read-only)

`plan` writes nothing. It reports what `install` would do.

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 plan --profile demo --target .\my-project
```

Read the JSON output. Confirm:

- `profile` is `demo`.
- `skills` lists `thinking-language`, `session-boot-ritual`, `aho-installer`, `demo-hello`.
- `projections` lists the platform directories that will be created (e.g. `.claude/skills`, `.opencode/skills`).
- `exit_code` is 0.

If you omit `--profile`, the CLI defaults to `demo`:

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 plan --target .\my-project
```

## 5. Install (writes — dual gate required)

`install` is dry-run by default. To materialize, pass both `--apply` and `--confirmed`:

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 install --profile demo --target .\my-project --apply --confirmed
```

**What this writes:**

- `.\my-project\.agents\skills\` — the four demo skills (source of truth).
- `.\my-project\.agents\settings.json` — project-level settings template.
- `.\my-project\AGENTS.md`, `CLAUDE.md`, `GEMINI.md` — agent instruction files.
- `.\my-project\.mcp.json` — empty MCP server template.
- Platform projection directories (e.g. `.\my-project\.claude\skills`) — junctions on Windows, copies on Linux/macOS.

**What this does NOT write:**

- No `settings.local.json` (credentials live in your environment, not in the tree).
- No `.env` file.
- No files outside `--target`.

Expected output: JSON with `exit_code: 0` and a list of installed skills.

## 6. Verify

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 verify --target .\my-project
```

Expected: JSON with `exit_code: 0` and `status: "ok"`. If `exit_code` is non-zero, proceed to [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## 7. Doctor (health check)

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 doctor --target .\my-project
```

Expected: JSON with `exit_code: 0` and no `error`-level findings. `doctor` checks projection integrity, settings schema, and skill completeness.

## 8. Scan (optional, read-only)

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 scan --target .\my-project
```

Reports any blocklisted paths or suspected secret patterns inside the target. Useful before committing your project.

## 9. Global setup (optional)

To install the global skill source at `~/.agents` (or a custom home):

```powershell
# Preview first (read-only)
.\apps\aho-setup\bin\aho-setup.ps1 global-plan --home .\test-home

# Materialize
.\apps\aho-setup\bin\aho-setup.ps1 global-setup --home .\test-home --apply --confirmed
```

`global-setup` does NOT overwrite existing global instruction files — it merges. See [CONFIGURATION.md](CONFIGURATION.md) for details.

## 10. Expected end state

```text
my-project/
  .agents/
    settings.json
    skills/
      thinking-language/
      session-boot-ritual/
      aho-installer/
      demo-hello/
  .claude/skills/      ← projection (junction or copy)
  .opencode/skills/    ← projection
  ... (other platform projections)
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  .mcp.json
```

Edit skills under `.agents/skills/` only. Never edit projection directories directly — they are regenerated from `.agents/`.

## 11. Language preference

Add `--lang zh-CN` for Chinese output, or set the `AHO_LANG` environment variable:

```powershell
$env:AHO_LANG = "zh-CN"
.\apps\aho-setup\bin\aho-setup.ps1 --help
```

## Next steps

- [CONFIGURATION.md](CONFIGURATION.md) — how to customize settings, MCP, and projections.
- [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md) — platform-specific behavior and limits.
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — diagnose failures.
