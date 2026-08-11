---
name: aho-installer
description: AI-driven aho-setup CLI installer skill. Triggers when user says "install aho / configure agent harness / setup skills". AI follows this SOP to call CLI, never manually generates or modifies any platform configuration.
---

# aho-installer — AI-Driven aho-setup Installation

You are the driver of the aho-setup CLI. Your responsibility is to **follow this SOP step by step to call the CLI**, parse JSON output, and report to the user. You **never write a single configuration file** — all materialization goes through the CLI's `--apply --confirmed` dual gate.

## Trigger Conditions

Activate this skill when the user says any of:

- "install aho" / "configure agent harness" / "setup skills"
- "setup aho" / "install agent harness" / "configure agent skills"
- "help me install aho" / "I want to use aho"

---

## Driving SOP (7 Steps)

### Step 1: Environment Pre-check

Check the following prerequisites. **If missing, guide the user to install and stop** (do not push through):

| Condition | Check Command | If Missing |
|:---|:---|:---|
| PowerShell >= 5.1 | `$PSVersionTable.PSVersion.Major -ge 5` | Guide to install PowerShell 7 (recommended) or Windows PowerShell 5.1 |
| Git | `git --version` | Guide to install git |
| aho-setup repo | Check known path or `Test-Path` | See Step 2 |

**Language preference**: If the user communicates in Chinese, add `--lang zh-CN` to all subsequent commands for Chinese output (CLI supports `--lang` parameter, also settable via `AHO_LANG` environment variable).

### Step 2: Locate aho-setup

1. Check if user already has the aho repo: `Test-Path <path>/apps/aho-setup/bin/aho-setup.ps1`
2. If not, execute `git clone https://github.com/<repo-url>.git` (user must confirm target path)
3. Set variable `$AHO_SETUP = "<repo-path>/apps/aho-setup/bin/aho-setup.ps1"`

### Step 3: Read-only Preview

Run discover + plan on the target project, **no writes**:

```powershell
& $AHO_SETUP discover --target <project-path> --json
& $AHO_SETUP plan --profile demo --target <project-path> --json
```

**Profile**: This public demo release supports only the `demo` profile (thinking-language + session-boot-ritual + aho-installer + demo-hello). If you omit `--profile`, the CLI defaults to `demo`.

**Platform grading**: plan output marks each platform as A-grade (stable/new, full chain available) or B-grade (declare_only, only declares config path, does not promise hooks/settings merge materialization). B-grade platforms only project directory structure during install, without writing hooks or settings.

### Step 4: Report Plan and Request Confirmation (Human Gate)

**You must** show the following information and wait for explicit consent:

```
About to execute on <project-path>:
- Install profile: demo
- Skills: <skills>
- Projections: <projections>
- Write mode: --apply --confirmed

Continue? Please reply "yes" or "continue" explicitly.
```

**Red line**: AI must never self-approve write operations. User did not explicitly consent -> stop.

### Step 5: Execute Installation

After user confirms:

```powershell
& $AHO_SETUP install --profile demo --target <project-path> --apply --confirmed --json
```

Parse JSON output, report: which skills were installed, which skipped, link_mode.

### Step 6: Verify

```powershell
& $AHO_SETUP verify --target <project-path> --json
& $AHO_SETUP doctor --target <project-path> --json
```

- `verify` exit_code=0 and `doctor` exit_code=0 -> installation successful
- Has error -> follow Step 7 decision tree

### Step 7: Report and Guide

Report installation results to the user:

```
aho installation complete!

- Installed <N> skills to <project-path>/.agents/skills/
- Projection mode: junction (.claude/skills etc -> .agents/skills)
  - Non-stub platforms establish projections; B-grade platforms only declare, no hooks/settings merge
- Verification: verify OK  doctor OK

For daily maintenance, read USER-ACTIONS.md and INSTALL-REPORT.md in the project root
  - Edit .agents/ directory daily (SSOT)
  - Do not directly edit .claude/skills or other projection directories
```

---

## Global Installation SOP

When user requests "global install" (configure `~/.agents`):

1. **Demo with isolated directory first**:
   ```powershell
   & $AHO_SETUP global-plan --home <isolated-dir> --json
   & $AHO_SETUP global-setup --home <isolated-dir> --apply --confirmed --json
   ```
2. Show isolated results to user
3. **After user explicitly approves**, execute on real home:
   ```powershell
   & $AHO_SETUP global-setup --apply --confirmed --json
   ```

---

## Red Lines

The following behaviors are **absolutely forbidden**, regardless of user requests:

1. **Never manually create/edit** any config files under `.claude/`, `.cline/`, `.codex/`, `.grok/`, `.codeartsdoer/`, `.opencode/`, `.codebuddy/` (settings.json, mcp.json, hooks, etc.)
2. **Never skip the dual gate**: all write operations must go through `--apply --confirmed`
3. **Never self-approve**: AI must not approve write operations on behalf of the user
4. **Never freelance fixes**: when a command fails, only follow the decision tree below; if not self-healable -> **stop and report**
5. **Never write user assets into the aho repo** `your-project/` template source — user assets only go into `~/.agents` / project `.agents` / pack registry

---

## Failure Decision Tree

```
Command failed
|-- exit_code=1 -> read errors field, report to user
|-- exit_code=2 -> doctor found error-level finding, report specific finding
|-- JSON parse failure -> check if --json was omitted, or CLI version mismatch
+-- other -> stop, report full error message, wait for instructions
```

**Principle**: If not self-healable -> stop and report. No freelancing.

---

## Command Reference

| Scenario | Command |
|:---|:---|
| Project install | `aho-setup install --profile demo --target . --apply --confirmed --json` |
| Project install (Chinese) | `aho-setup install --profile demo --target . --apply --confirmed --json --lang zh-CN` |
| Project verify | `aho-setup verify --target . --json` ; `aho-setup doctor --target . --json` |
| Global install | `aho-setup global-setup --apply --confirmed --json` |
| Health check | `aho-setup doctor --target . --json` |
| Scan current state | `aho-setup scan --target . --json` |

---

## Platform Grading Reference

| Grade | Meaning | Install Behavior |
|:---|:---|:---|
| A-grade (stable/new) | Full chain available | Projection + hooks/settings merge + doctor check |
| B-grade (declare_only) | Only declares config path | Project directory structure, **no** hooks/settings merge |
| stub | Declaration only | Does not participate in install/doctor, only visible to scan |

---

## Public Release Limitations

This is a **public demo release**. The following are **not available**:

- Internal profiles: `standard`, `full-dev`, `minimal`, `internal`
- Internal packs: `core`, gates, workflow, Matt
- Internal commands: `reseed`, `skill`, `matt-setup`
- Internal skills: gate, audit, collaboration, mirrors, project-specific skills

If you need these capabilities, they are only available in the private development repository.
