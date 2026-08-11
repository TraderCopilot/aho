# Contributing

Thank you for your interest in `agents-harness-os`. This repository is a **generated public demo release** — it is not the source of truth.

## Where to contribute

This tree is produced by a `pack-release.ps1` script from a private development repository. **Do not submit pull requests against generated files** — they will be overwritten on the next release.

### Bugs and feature requests

Open a GitHub issue with:
1. A clear title and description.
2. Steps to reproduce (for bugs) or use case (for features).
3. The output of `.\apps\aho-setup\bin\aho-setup.ps1 doctor --target <path> --json` if applicable.
4. Your PowerShell version (`$PSVersionTable.PSVersion`).

### Security vulnerabilities

Do NOT open a public issue. Use **GitHub Security Advisory** (Settings > Security > Security advisories). See [SECURITY.md](SECURITY.md) and [docs/SECURITY.md](docs/SECURITY.md).

## What you can safely do with this release

- Clone and use it to install the `demo` profile in your projects.
- Report bugs and request features via issues.
- Suggest documentation improvements via issues.

## What you cannot do

- Submit PRs that modify generated content (skills, profiles, packs, platform definitions).
- Add new profiles, packs, or commands — these require changes in the source repository.
- Push directly to `main` — all changes go through pull request review.

## Release process (for maintainers)

1. Changes are made in the private development repository.
2. `pack-release.ps1` generates a new release tree.
3. `test-release.ps1` and `verify-release.ps1` must pass.
4. The release tree is committed to this repository with an incremented version tag.
5. GitHub Actions CI runs on push and must pass before release.
