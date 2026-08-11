# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| 0.x (public demo) | Yes |
| < 0.x | No |

## Reporting a Vulnerability

If you discover a security vulnerability in agents-harness-os, please report it responsibly:

1. **Do NOT open a public GitHub issue** for security vulnerabilities.
2. Use **GitHub Security Advisory** (Settings > Security > Security advisories > Report a vulnerability).
3. Provide a clear description of the vulnerability, steps to reproduce, and potential impact.
4. You will receive a response within 72 hours acknowledging receipt.

We ask that you:
- Give us reasonable time to investigate and fix the issue before any public disclosure.
- Do not access or modify data that does not belong to you.

## Security Principles

### Secrets and Credentials

- **Never hardcode** API keys, tokens, passwords, or private keys in any file.
- Use **environment variables** or local `.env` files (which must be gitignored).
- The installer never writes `settings.local.json` or credential files.

### What Should Never Be Committed

- `.env` files (containing real environment variable values)
- `.ssh/` directories (containing private keys)
- Any file containing `BEGIN OPENSSH PRIVATE KEY`, `BEGIN RSA PRIVATE KEY`, or `BEGIN EC PRIVATE KEY`
- API keys matching patterns like `sk-...`, Bearer tokens, or cloud provider credentials
- Personal configuration with real account names, emails, or internal hostnames

### Built-in Scanning

The release tree includes a secret/block scanner (`aho-setup scan`) that checks for:
- Blocklisted paths (`.env`, `.ssh/`, cache directories, internal tooling)
- Private key headers
- Common API token patterns
- Bearer tokens

The pack script runs a final scan on all generated files before promotion. Any hit causes the build to fail.

### Release Tree Integrity

- The release tree is a generated artifact. Do not hand-edit business content.
- `RELEASE-MANIFEST.json` contains file hashes for integrity verification.
- The pack script uses a staging directory and controlled promotion to prevent corruption of existing releases.
