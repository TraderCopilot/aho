# agents-harness-os (public demo release)

A safe, idempotent installer that projects a single source of truth (`.agents/`) into multiple AI coding agent platforms (Claude Code, OpenCode, CodeArts, Grok, and more).

**Version:** 0.5.0 (public demo)  
**License:** Apache-2.0  
**Status:** Public demo release — not a 1.0 production release.

> **Generated tree — do not hand-edit.** This tree is produced by the `pack-release.ps1` pack script from the private development repository. Fixes must go back to the source, not into this tree.

## Quick start (5 minutes)

```powershell
# 1. Clone this repository to a local path
git clone <this-repo-url> aho-demo
cd aho-demo

# 2. Preview the install plan (read-only, writes nothing)
.\apps\aho-setup\bin\aho-setup.ps1 plan --profile demo --target .\my-project

# 3. Install (writes to .\my-project — requires dual gate)
.\apps\aho-setup\bin\aho-setup.ps1 install --profile demo --target .\my-project --apply --confirmed

# 4. Verify and diagnose
.\apps\aho-setup\bin\aho-setup.ps1 verify --target .\my-project
.\apps\aho-setup\bin\aho-setup.ps1 doctor --target .\my-project
```

If `verify` and `doctor` both exit with code 0, the installation is healthy.

## What this release gives you

| Category | Supported | Not supported |
|:---|:---|:---|
| Profile | `demo` | `standard`, `full-dev`, `minimal`, `internal` |
| Pack | `demo-core` | `core`, gates, workflow, Matt, internal packs |
| Commands | `discover`, `scan`, `plan`, `install`, `verify`, `doctor`, `global-plan`, `global-setup` | `reseed`, `skill`, `matt-setup` |
| Skills | `thinking-language`, `session-boot-ritual`, `aho-installer`, `demo-hello` | gate, audit, collaboration, mirrors, project-specific skills |
| Platforms | 18 platforms (see `docs/PLATFORM_SUPPORT.md`) | — |

Omitting `--profile` defaults to `demo`. Passing any unsupported profile exits with a clear error.

## Support matrix

- **Windows PowerShell 5.1** — supported (entry script, help, demo smoke tested).
- **PowerShell 7** — supported.
- **Linux / macOS PowerShell** — best-effort; file projection works, junctions degrade to copies (see `docs/PLATFORM_SUPPORT.md`).

## Documentation

| Document | Audience |
|:---|:---|
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | New users — prerequisites, first install, expected output |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Users who need to configure or customize the install |
| [docs/PLATFORM_SUPPORT.md](docs/PLATFORM_SUPPORT.md) | Multi-platform users — support matrix, projection behavior, limits |
| [docs/SECURITY.md](docs/SECURITY.md) | All users — secrets, scanning, vulnerability reporting |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Users hitting failures — diagnosis and recovery |
| [CHANGELOG.md](CHANGELOG.md) | Anyone tracking changes |
| [docs/RELEASE-CONTRACT.md](docs/RELEASE-CONTRACT.md) | Maintainers — release contract and boundaries |

## Verification checklist (from zero)

```text
--help                  → prints commands, allowed profiles: demo
plan   --target .\p     → dry-run plan, exit 0
install --profile demo --target .\p --apply --confirmed  → exit 0
verify --target .\p     → exit 0
doctor --target .\p     → exit 0
```

## Release integrity

- `RELEASE-MANIFEST.json` lists every shipped file with a SHA-256 hash and no machine-local paths.
- `apps/aho-setup/bin/verify-release.ps1` scans the tree (path blocklist + content rules + manifest hashes) and fails closed on any hit.
- `apps/aho-setup/bin/rebuild-manifest.ps1` regenerates the manifest after any approved change.

## Reporting issues

- Bugs and feature requests: open a GitHub issue.
- Security vulnerabilities: do NOT open a public issue — use GitHub Security Advisory (see `docs/SECURITY.md`).

## License

Apache-2.0 — see [LICENSE](LICENSE).
