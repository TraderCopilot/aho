# Security

This document expands on the root [SECURITY.md](../SECURITY.md) with configuration-level guidance for users of the public demo release.

## 1. Supported versions

| Version | Supported |
|:---|:---|
| 0.x (public demo) | Yes |
| < 0.x | No |

## 2. Reporting a vulnerability

1. **Do NOT open a public GitHub issue** for security vulnerabilities.
2. Use **GitHub Security Advisory** (Settings > Security > Security advisories > Report a vulnerability).
3. Provide a clear description, steps to reproduce, and potential impact.
4. You will receive an acknowledgment within 72 hours.

We ask that you:
- Give us reasonable time to investigate and fix before any public disclosure.
- Do not access or modify data that does not belong to you.

## 3. Secrets and credentials — principles

- **Never hardcode** API keys, tokens, passwords, or private keys in any file.
- Use **environment variables** or local `.env` files (which must be gitignored).
- The installer **never** writes `settings.local.json` or credential files.
- All examples in this release use placeholders or environment variable names — never real secrets.

## 4. What should never be committed

| Pattern | Why |
|:---|:---|
| `.env` files | Contain real environment variable values. |
| `.ssh/` directories | Contain private keys. |
| `*.local.json` | Machine-local settings, often with secrets. |
| Files containing `BEGIN OPENSSH PRIVATE KEY`, `BEGIN RSA PRIVATE KEY`, `BEGIN EC PRIVATE KEY`, `BEGIN PGP PRIVATE KEY BLOCK` | Private key material. |
| Strings matching `sk-...` (OpenAI / Anthropic style) | API tokens. |
| Strings matching `gh[pousr]_...` | GitHub tokens. |
| Strings matching `glpat-...` | GitLab tokens. |
| Strings matching `xox[baprs]-...` | Slack tokens. |
| `Bearer <long-token>` | Bearer tokens. |
| Personal email addresses | Personal identifiable information. |
| Absolute paths like `C:\Users\...` or `/Users/...` | Machine-local paths. |

## 5. Built-in scanning

### 5.1 Project scan

```powershell
.\apps\aho-setup\bin\aho-setup.ps1 scan --target .\my-project
```

Scans the target directory for blocklisted paths and suspected secret patterns. Reports file path and rule ID only — never echoes the suspected content.

### 5.2 Release tree scan

```powershell
.\apps\aho-setup\bin\verify-release.ps1 <release-root>
```

Runs three layers of checks on the release tree:

1. **Path blocklist** — `.env`, `.ssh/`, cache directories, internal tooling, session handover files, etc.
2. **Content rules** — private key headers, API tokens, bearer tokens, machine-local paths, personal emails.
3. **Manifest verification** — every file in `RELEASE-MANIFEST.json` must exist, match its SHA-256 hash, and have no extra files.

Any hit causes exit code 1 (fail-closed).

## 6. Safe configuration examples

### 6.1 MCP server with environment variable

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

Set `EXAMPLE_API_KEY` in your shell:

```powershell
$env:EXAMPLE_API_KEY = "your-key-here"
```

### 6.2 Settings with no secrets

```json
{
  "aho": {
    "schema_version": "1",
    "scope": "project",
    "language": "zh-CN"
  }
}
```

### 6.3 .gitignore for your project

```text
.env
.env.*
*.local.json
.ssh/
```

## 7. Release tree integrity

- `RELEASE-MANIFEST.json` contains SHA-256 hashes for every shipped file and no machine-local paths.
- `verify-release.ps1` detects missing, extra, or modified files.
- The pack script uses a staging directory and controlled promotion — a failed build does not corrupt an existing release.
- `pack-release.ps1` dry-run writes nothing; `CleanOut` requires a `.aho-release-marker` file in the target and refuses filesystem roots.

## 8. What the installer never does

- Writes `settings.local.json` or any credential file.
- Reads or copies from your `~/.ssh`, `~/.env`, or personal HOME.
- Sends telemetry or network requests.
- Executes user-supplied code during install.
- Deletes directories without a controlled marker.
