# Changelog

All notable changes to sage-code will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-17

Brings the plugin in line with the current Claude Code plugin, hook, skill, and subagent conventions. In 0.1.0 the hooks did not receive real event data, so no session events were captured.

### Changed
- Hook scripts read their input as JSON from stdin: `session_id`, `prompt`, `tool_name`, `tool_input`, `source`, and `reason`. They no longer use the `CLAUDE_SESSION_ID`, `$TOOL_INPUT`, or `$USER_INPUT` environment variables, which Claude Code does not set
- `hooks.json` uses exec form (`command` + `args`) with `${CLAUDE_PLUGIN_ROOT}` in place of `$CLAUDE_PLUGIN_DIR`, and has a top-level `description`
- The session summary is written by a `SessionEnd` hook in place of `Stop`. `Stop` fires at the end of each turn, so it wrote one `session_end` event per turn
- Tool failures come from the `PostToolUseFailure` event in place of a regex on the tool output. Failure events have an `error` excerpt
- The SessionStart hook runs synchronously and returns `hookSpecificOutput.additionalContext` in place of `systemMessage`, so the replay notice reaches Claude. It is silent when there is nothing to replay
- The SessionStart hook counts a session one time only, not again on resume or compaction
- The project directory comes from `CLAUDE_PROJECT_DIR`
- Skills dispatch subagents by their scoped names (`sage-code:reflector`, ...) and find the current event log with `${CLAUDE_SESSION_ID}`
- `sage-replay` and `sage-reflect` pre-approve the `rm` and `git diff` commands that they use
- `plugin.json` has the correct repository URL, plus `displayName`, `homepage`, and `keywords`. The version is set in `plugin.json` only
- `marketplace.json` has a description
- `run-all.sh` finds `bats` on `PATH` and works from any directory
- The test suite sends the same payloads that Claude Code sends (86 tests)

### Added
- `name` field in all subagent definitions
- `session_start` events record `source`; `session_end` events record `reason`
- Session IDs are made safe before use in a file name

### Removed
- `asyncTimeout` hook field, which Claude Code does not have

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
