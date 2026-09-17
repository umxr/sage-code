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
- Bash
- Python 3 (for JSON parsing in hook scripts)
- Git
- [bats-core](https://github.com/bats-core/bats-core) (for the tests)
- A current version of Claude Code (for `claude plugin validate` and `claude --plugin-dir`; tested with v2.1.274)

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
3. Set `SAGE_PROJECT_DIR` to the temp directory
4. Pipe a hook payload into the script. Use the builders in `test_helper.bash` (`session_start_payload`, `tool_payload`, `tool_failure_payload`, `prompt_payload`, `session_end_payload`). They print the same JSON that Claude Code sends on stdin
5. Assert on the event log contents
6. Clean up

Hook scripts must read `session_id` and all other event data from the stdin JSON. Do not read them from environment variables. See the [hooks reference](https://code.claude.com/docs/en/hooks) for the input of each event.

Run all tests, then validate the manifests:
```bash
bash sage-code/tests/run-all.sh
claude plugin validate . --strict
claude plugin validate ./sage-code --strict
```

To try your change in a real session, run `claude --plugin-dir ./sage-code` in a scratch project.

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
