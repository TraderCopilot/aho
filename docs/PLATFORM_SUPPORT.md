# Platform Support

This document lists the 18 platforms declared in this release, their support grade, projection behavior, and known limitations.

## 1. Support matrix

| Platform | Display name | Status | Grade | Project projection | Global projection |
|:---|:---|:---|:---|:---|:---|
| claude | Claude Code | stable | A | `.claude/skills` | `~/.claude/skills` |
| codearts | CodeArts | stable | A | `.codeartsdoer/skills` | `~/.codeartsdoer/skills` |
| codebuddy | CodeBuddy | stable | A | `.codebuddy/skills` | `~/.codebuddy/skills` |
| codex | OpenAI Codex | stable | A | `.codex/skills` | `~/.codex/skills` |
| grok | Grok | stable | A | `.grok/skills` | `~/.grok/skills` |
| opencode | OpenCode | stable | A | `.opencode/skills` | `~/.config/opencode/skills` |
| amp | Amp | new | B | `.amp/skills` | `~/.amp/skills` |
| antigravity | Antigravity | new | B | declared only | declared only |
| cline | Cline | new | B | `.cline/skills` | `~/.cline/skills` |
| command-code | Command Code | new | B | declared only | declared only |
| copilot | GitHub Copilot CLI | new | B | declared only | declared only |
| cursor | Cursor | new | B | declared only | declared only |
| devin | Devin | new | B | declared only | declared only |
| droid | Factory Droid | new | B | declared only | declared only |
| gemini | Gemini CLI | new | B | `.gemini/skills` | `~/.gemini/skills` |
| kimi | Kimi Code | new | B | declared only | declared only |
| openclaude | OpenClaude | new | B | declared only | declared only |
| pi | Pi | new | B | declared only | declared only |

### Grade definitions

| Grade | Meaning | Install behavior |
|:---|:---|:---|
| A (stable) | Full chain available. | Projection + settings merge + doctor check. (Hooks would be merged if hook templates were shipped; this demo ships none.) |
| B (new / declare_only) | Platform is declared; config path is known. | Directory projection only. No settings merge or hooks. |
| stub | Declaration only. | Does not participate in install or doctor. Visible to `scan` only. |

No platform in this release is marked `stub`. All 18 are at least B-grade (directory projection).

## 2. Projection mechanism

Every platform projects from the single source of truth `.agents/skills/` into its native skills directory.

### Windows (junction)

On Windows, the installer creates a **directory junction** (a reparse point) from the platform directory to `.agents/skills/`. This means:

- Edits in `.agents/skills/` are instantly visible in every projection.
- No disk duplication.
- Junctions are transparent to the agent — it reads the platform directory as if it contained the files.

### Linux / macOS (copy)

Junctions are a Windows feature. On Linux and macOS, the installer falls back to **recursive copy**:

- The platform directory contains a snapshot of `.agents/skills/`.
- Edits in `.agents/` are NOT automatically reflected in projections.
- Re-run `install` after editing `.agents/` to refresh projections.

This is the only behavioral difference between platforms. The source of truth (`.agents/`) is identical.

## 3. Permissions and degradation

| Scenario | Behavior |
|:---|:---|
| Target directory not writable | `install` fails with a clear error. No partial state. |
| Junction creation fails (permissions) | Falls back to copy. `doctor` reports the degradation as a warning. |
| Platform directory already exists with content | Installer merges; existing files are overwritten only if they match a skill being installed. |
| Symlink encountered where junction expected | Installer skips and reports. |

## 4. Platform-specific notes

### Claude Code (`claude`)

- Project settings: `.claude/settings.json` (deep-merged).
- Forbidden: `.claude/settings.local.json` (never written by installer).
- Hooks: the platform supports hooks in `.claude/settings.json` under the `hooks` key, but this demo release does not ship hook templates, so no hooks are written during install.

### OpenCode (`opencode`)

- Project skills project to `.opencode/skills`.
- Global skills project to `~/.config/opencode/skills` (NOT `~/.opencode/skills` — the latter is not scanned by OpenCode).
- Agents directory: `.opencode/agents` (markdown format).

### CodeArts (`codearts`)

- Project skills project to `.codeartsdoer/skills`.
- Settings: `.codeartsdoer/config.json`.

### Grok (`grok`)

- Project skills project to `.grok/skills`.
- Settings: `.grok/config.json`.

### Gemini CLI (`gemini`)

- B-grade in this release. Directory projection only; no settings merge.

## 5. Discovering what is installed

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 discover --target .\my-project
```

Returns JSON listing detected platform directories, their grade, and whether projections are intact.

## 6. Limitations

- **No platform-specific skill variants.** All platforms receive the same four demo skills. If a platform does not support a skill's syntax, the skill is still projected; the agent may ignore it.
- **No platform hooks in this release.** The demo release does not ship hook templates. `Hooks.ps1` is a merge library that activates only when hook templates are present; the current demo has none, so no platform receives hooks during install. A-grade platforms still receive projections and settings merge; B-grade platforms receive directory projection only.
- **No automatic platform upgrade.** A B-grade platform cannot be upgraded to A-grade by configuration. Upgrading requires changes in the source repository and a new release.
- **Linux/macOS copies are not live.** Re-run `install` after editing `.agents/` to refresh projections on non-Windows platforms.

## 7. Adding a platform not in the list

You cannot add a platform from within this release. The platform registry (`apps/aho-setup/platforms/*.yaml`) is part of the generated tree and must not be hand-edited. To propose a new platform, open an issue in the source repository.
