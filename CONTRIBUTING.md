# Contributing to sage-code

Thanks for your interest in contributing! Here's how to get started.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/sage-code.git`
3. Create a branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Run tests: `bash sage-code/tests/run-all.sh`
6. Commit with a descriptive message
7. Push and open a Pull Request

## Development Setup

No special setup required. The plugin is pure bash + markdown. You need:
- Bash 4+
- Python 3 (for JSON parsing in hook scripts)
- Git

## Project Structure

```
sage-code/                    # The plugin
├── hooks/scripts/            # Shell scripts that capture session events
├── agents/                   # Subagent definitions (markdown)
├── skills/                   # Skill definitions (markdown)
├── bin/                      # Bootstrap scripts
├── templates/                # Default config and templates
└── tests/                    # Test suites
```

## Writing Tests

Every hook script has a corresponding test in `sage-code/tests/`. Follow the existing pattern:

1. Create a temp directory
2. Bootstrap `.sage/` with `sage-init.sh`
3. Set env vars (`SAGE_PROJECT_DIR`, `CLAUDE_SESSION_ID`)
4. Run the hook with mock input
5. Assert on the event log contents
6. Clean up

Run all tests with:
```bash
bash sage-code/tests/run-all.sh
```

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include tests for new hook scripts or behavioral changes
- Update the README if you add new commands or change behavior
- Follow the existing code style (shellcheck-clean bash, consistent JSON structure)

## Reporting Bugs

Open an issue with:
- What you expected to happen
- What actually happened
- Your Claude Code version (`claude --version`)
- Your OS

## Feature Requests

Open an issue describing:
- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered

## Code of Conduct

Be respectful and constructive. We're all here to make Claude Code better.
