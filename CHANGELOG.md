# Changelog

All notable changes to agents-harness-os (public demo release) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-08-12

### Added
- Public demo release with `demo` profile and `demo-core` pack.
- Distribution mode configuration (`distribution.json`) for public release behavior.
- Safe pack script (`pack-release.ps1`) with dry-run zero-write, controlled CleanOut, and staging promotion.
- `LICENSE` (Apache-2.0), `SECURITY.md`, `CHANGELOG.md`.
- Release contract documentation (`docs/RELEASE-CONTRACT.md`).
- Public documentation: `README.md`, `docs/GETTING_STARTED.md`, `docs/CONFIGURATION.md`, `docs/PLATFORM_SUPPORT.md`, `docs/TROUBLESHOOTING.md`.

### Changed
- CLI default profile changed from `standard` to `demo` when `distribution.json` is present.
- CLI help dynamically hides disabled commands based on distribution configuration.
- `RELEASE-MANIFEST.json` no longer contains local machine paths (`repo_root`, `out_root`); uses product name, version, and relative file paths with SHA-256 hashes.
- UTF-8 BOM added to all PowerShell scripts containing non-ASCII characters for Windows PowerShell 5.1 compatibility.

### Removed
- `core` pack (internal-only, depended on `agent-harness-os` skill).
- `minimal` profile (referenced removed `core` pack).
- Internal commands (`reseed`, `skill`, `matt-setup`) from public help and command dispatch.
- Internal profile references (`standard`, `full-dev`) from public `aho-installer` skill documentation.

### Security
- Extended blocklist with additional path patterns and content scan rules.
- Manifest verification command added to detect missing, extra, or modified files.
- Pack script refuses filesystem root as output path.
- CleanOut requires `.aho-release-marker` file in target directory.
