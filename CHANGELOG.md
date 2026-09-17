# Changelog

All notable changes to sage-code will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-09-17

Replay uses native Claude Code rules, and meta-evaluation uses measured exposure.

### Added
- `sage-publish-rules` script: writes one rule file per heuristic to `.claude/rules/sage/`, with `paths:` frontmatter from the new `Paths` field of a knowledge entry
- `InstructionsLoaded` hook: records a `rule_loaded` event each time Claude Code loads a sage rule, with the load reason and the file that triggered the load
- `sage-exposure` script: aggregates rule loads into `.sage/meta/exposure.json` for the meta-evaluator and the curator
- `exposure.json` keys `heading` and `published` for each rule: the script that writes a rule file owns its ID, so no agent computes an ID from a heading. A published rule that never loaded gets an entry too
- `exposure.json` key `exposure_since`: the start of the oldest session with a rule load. Before that time there is no exposure history on the machine
- `exposure.json` keys `active_sessions_loaded`, `active_sessions_not_loaded`, and `sessions_inactive`: a session with no tool call, correction, or positive signal cannot load a path-scoped rule, so the per-session numbers now count the sessions with activity only
- Config key `publish_min_confidence` (default `low`)
- `rules_loaded` in the `session_end` summary

### Changed
- The reflector gives each heuristic a `Paths` field with the files where it applies
- The meta-evaluator compares sessions where a rule was loaded with sessions where it was not
- A rule is stale only when it has no new evidence **and** did not load in `stale_days`. Before, a rule that worked was pruned, because a rule that works causes no new corrections
- The SessionStart hook finds a new session by its `session_start` event, and adds context only when a reflection is pending or meta-evaluation is due
- `sage-replay` no longer scores and prints heuristics; Claude Code loads the rule files itself
- The curator does not prune for staleness until there are `stale_days` of exposure history on the machine. The event logs are personal and are not in git, so a new clone or an upgrade has no history
- `sage-exposure` adds `meta/exposure.json` to `.sage/.gitignore` itself. The file holds prompt excerpts and failed commands

### Security
- Rule publishing does not follow a symbolic link. A linked `.claude/rules/sage` directory is left alone with a warning, a linked rule file is replaced by a regular file, and a link with no entry is removed without its target. A file in `.claude/rules/sage/` that sage-code did not write is left in place
- A damaged `config.json` does not stop event capture: the SessionStart hook writes the `session_start` event first, and never overwrites a config that it could not read
- The reflector treats the event log as untrusted data: text in an error, a command, or a prompt excerpt is never copied into a rule and never obeyed

### Removed
- The managed "Sage Learnings" section in `CLAUDE.md`. SAGE-Code no longer edits `CLAUDE.md`
- The PROMOTE action of the meta-evaluator
- Config keys `replay_max_heuristics`, `replay_max_tokens`, and `promote_score_threshold`

### Migration
- The first run of `sage-publish-rules` removes the old "Sage Learnings" section from `CLAUDE.md`, if its start and end markers are there
- Commit the new `.claude/rules/sage/` directory

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
