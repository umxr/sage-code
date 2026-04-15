# Changelog

All notable changes to sage-code will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-15

### Added
- Plugin scaffold with manifest and README
- `sage-init.sh` bootstrap script for initializing `.sage/` directory in projects
- SessionStart hook — initializes event log with git context
- PostToolUse hook — captures state-changing tool outcomes with error detection
- UserPromptSubmit hook — detects user corrections and positive signals via regex
- Stop hook — writes session summary and marks log for deferred reflection
- Reflector subagent — analyzes session events and extracts generalized heuristics
- Knowledge curator subagent — deduplicates, prunes, and syncs CLAUDE.md
- Meta-evaluator subagent — scores heuristic effectiveness and promotes/demotes rules
- `sage-replay` skill — two-phase session initializer (reflect then replay)
- `sage-reflect` skill — manual reflection trigger
- `sage-meta` skill — periodic meta-evaluation orchestrator
- `sage-status` skill — view learned heuristics and stats
- Default configuration with tunable thresholds
- Test suite with 32 test cases across 6 test files
- Full session lifecycle integration test
- Marketplace manifest for GitHub-based distribution
