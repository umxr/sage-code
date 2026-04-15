# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in sage-code, please report it responsibly:

1. **Do not** open a public issue
2. Email the maintainers or use [GitHub's private vulnerability reporting](https://github.com/umxr/sage-code/security/advisories/new)
3. Include a description of the vulnerability and steps to reproduce

We will acknowledge receipt within 48 hours and aim to release a fix within 7 days for critical issues.

## Security Considerations

sage-code captures session data in `.sage/events/` which may contain:
- User prompts (including corrections)
- Tool inputs and outputs
- File paths and git context

The `.sage/events/` directory is gitignored by default to prevent accidental commit of personal session data. The `.sage/knowledge/` directory is designed to be committed and shared — it contains only generalized heuristics, not raw session data.

### Hook Script Safety

All hook scripts:
- Run with `set -euo pipefail` for strict error handling
- Execute asynchronously (never block the user's session)
- Exit silently on missing `.sage/` directory
- Use no network access
- Write only to the `.sage/` directory
