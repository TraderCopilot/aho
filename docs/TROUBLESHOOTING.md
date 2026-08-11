# Troubleshooting

This document covers the most common failures and their resolution. If your issue is not listed here, run `doctor` and `scan`, then open a GitHub issue with the JSON output.

## 1. Prerequisite failures

### 1.1 PowerShell version too old

**Symptom:** `aho-setup.ps1` fails to parse or `$PSVersionTable.PSVersion.Major -lt 5`.

**Fix:** Install PowerShell 7 from <https://github.com/PowerShell/PowerShell>. The entry script requires PowerShell 5.1 at minimum; PowerShell 7 is recommended.

### 1.2 Git not found

**Symptom:** `git --version` fails.

**Fix:** Install Git from <https://git-scm.com>. Git is only needed to clone this repository; the installer itself does not call Git.

### 1.3 Entry script not found

**Symptom:** `Test-Path .\apps\aho-setup\bin\aho-setup.ps1` returns `False`.

**Fix:** You are not in the release tree root. `cd` to the directory where you cloned/extracted the release. If the file is genuinely missing, re-clone or re-extract.

## 2. Plan failures

### 2.1 Unsupported profile

**Symptom:**

```text
This distribution does not support profile 'standard'. Allowed profiles: demo
```

**Cause:** You passed `--profile standard` (or `full-dev`, `minimal`, etc.).

**Fix:** Use `--profile demo`, or omit `--profile` (defaults to `demo`).

### 2.2 Missing --target

**Symptom:** `plan requires --target` (or `install requires --target`, etc.).

**Fix:** Pass `--target <path>`.

### 2.3 Target path is a filesystem root

**Symptom:** `install` refuses with a root-path error.

**Fix:** Choose a non-root path. The installer refuses `C:\`, `/`, and similar roots for safety.

## 3. Install failures

### 3.1 Write refused (dry-run)

**Symptom:** `DRY-RUN: no files written. Pass --apply --confirmed to materialize.`

**Cause:** You omitted `--apply`, `--confirmed`, or both.

**Fix:** Add both flags:

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 install --profile demo --target .\my-project --apply --confirmed
```

This dual gate is intentional — it prevents accidental writes.

### 3.2 Target directory not writable

**Symptom:** `install` fails with a permissions error.

**Fix:** Check the ACL on the target directory. The installer needs write permission. On Windows, run your shell as a normal user (not administrator) unless the target is under an admin-only path.

### 3.3 Junction creation failed

**Symptom:** `doctor` reports a warning that projection fell back to copy.

**Cause:** On Windows, junction creation can fail due to permissions, antivirus, or the target being on a different volume.

**Fix:** This is a **warning**, not an error. The install is functional; projections are copies instead of junctions. Re-run `install` after editing `.agents/` to refresh the copies. If you want junctions, check that the target and `.agents/` are on the same volume and that junction creation is not blocked by policy.

### 3.4 Disabled command invoked

**Symptom:**

```text
Command 'reseed' is not available in this distribution. This is a public demo release; internal commands are disabled.
```

**Cause:** You invoked `reseed`, `skill`, or `matt-setup`.

**Fix:** These commands are intentionally disabled in the public demo release. There is no workaround within this release.

## 4. Verify failures

### 4.1 Missing projection

**Symptom:** `verify` reports a missing projection directory (e.g. `.claude/skills` not found).

**Cause:** The projection was not created, or was deleted after install.

**Fix:** Re-run `install`:

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 install --profile demo --target .\my-project --apply --confirmed
```

### 4.2 Projection out of sync

**Symptom:** `verify` reports that a projection's content does not match `.agents/skills/`.

**Cause:** Someone edited the projection directory directly, or `.agents/` was edited without re-installing.

**Fix:** Re-run `install`. Never edit projection directories directly — always edit `.agents/` and re-install.

### 4.3 Missing skill

**Symptom:** `verify` reports a missing skill under `.agents/skills/`.

**Fix:** Re-run `install`. If the skill is still missing, the release tree may be corrupted — re-clone and re-install.

## 5. Doctor failures

### 5.1 Error-level finding

**Symptom:** `doctor` exits with code 2 and reports an error-level finding.

**Fix:** Read the `findings` array in the JSON output. Each finding has a `category`, `severity`, and `message`. Address each error-level finding, then re-run `doctor`.

### 5.2 Settings schema mismatch

**Symptom:** `doctor` reports that `.agents/settings.json` does not match the schema.

**Fix:** Compare your `settings.json` to the template shipped with this release. Remove unrecognized keys or restore required keys. The installer does not validate arbitrary user-added keys; only the `aho` namespace is schema-checked.

## 6. Scan findings

### 6.1 Blocklisted path present

**Symptom:** `scan` reports a blocklisted path (e.g. `.env`, `.ssh/`).

**Fix:** Remove the file or directory. These are blocked because they typically contain secrets or machine-local data. Add the path to your project `.gitignore` if it should exist locally but not be committed.

### 6.2 Suspected secret pattern

**Symptom:** `scan` reports a content rule hit (e.g. `TOKEN-SK`, `KEY-OPENSSH`).

**Fix:** Remove the secret from the file. Use environment variables instead. See [SECURITY.md](SECURITY.md) for the full list of patterns.

## 7. Global setup issues

### 7.1 Existing global config not overwritten

**Symptom:** `global-setup` did not update your existing `~/.agents/AGENTS.md`.

**Cause:** This is intentional. `global-setup` merges; it does not overwrite existing instruction files.

**Fix:** If you want the new template, back up your existing file, delete it, then re-run `global-setup`. Or manually merge the differences.

### 7.2 Isolated home test

To test `global-setup` without touching your real home:

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 global-setup --home .\test-home --apply --confirmed
```

Inspect `.\test-home\.agents\`, then delete `.\test-home` when done.

## 8. Linux / macOS issues

### 8.1 Projections are copies, not junctions

**Symptom:** Editing `.agents/skills/` does not update `.claude/skills/` on Linux/macOS.

**Cause:** Junctions are Windows-only. On Unix, the installer copies.

**Fix:** Re-run `install` after editing `.agents/`.

### 8.2 PowerShell 7 not found

**Symptom:** `pwsh` command not found.

**Fix:** Install PowerShell 7 for your platform: <https://github.com/PowerShell/PowerShell>. Use `pwsh` instead of `powershell`.

## 9. Release tree issues

### 9.1 Manifest verification fails

**Symptom:** `verify-release.ps1` reports `MAN-HASH-MISMATCH` or `MAN-MISSING`.

**Cause:** A file in the release tree was modified, added, or deleted after the manifest was generated.

**Fix:** Re-clone the repository. If you are a maintainer, regenerate the manifest:

```powershell
.\apps\aho-setup\bin\rebuild-manifest.ps1 <release-root>
```

### 9.2 Scan of release tree fails

**Symptom:** `verify-release.ps1` reports a `BLK-PATH` or content rule hit.

**Fix:** Do not hand-edit the release tree. Re-clone. If you are a maintainer, the hit indicates a problem in the source repository — fix it there and regenerate the release.

## 10. Known limitations

- **No custom profiles.** Only `demo` is supported.
- **No internal commands.** `reseed`, `skill`, `matt-setup` are disabled.
- **B-grade platforms receive no hooks.** This is by design, not a bug.
- **Linux/macOS projections are not live.** Re-run `install` after editing `.agents/`.
- **No upgrade path within this release.** To upgrade, obtain a newer release and re-install.

## 11. Getting more help

1. Run `doctor --target <path> --json` and `scan --target <path> --json`.
2. Search existing GitHub issues.
3. Open a new issue with the JSON output of `doctor` and `scan`, plus the exact command you ran and the PowerShell version (`$PSVersionTable.PSVersion`).
4. For security issues, do NOT open a public issue — use GitHub Security Advisory (see [SECURITY.md](SECURITY.md)).
