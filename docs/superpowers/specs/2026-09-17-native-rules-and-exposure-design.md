# SAGE-Code: Native Rules and Measured Exposure

**Date:** 2026-09-17
**Status:** Approved design
**Author:** Claude + Umar
**Target version:** 0.3.0
**Builds on:** [2026-04-15 SAGE-Code design](2026-04-15-sage-code-design.md)

## Overview

This design changes two layers of SAGE-Code.

- **Layer 4 (Replay)** stops scoring heuristics in a skill. It publishes each heuristic as a file in `.claude/rules/sage/`. Claude Code loads these files itself, and it loads a path-scoped rule only when Claude reads a file that matches.
- **Layer 5 (Meta-learning)** stops guessing whether a rule was in use. An `InstructionsLoaded` hook records each rule that Claude Code loads, in each session. The meta-evaluator uses this exposure data.

**Why.** Claude Code now has built-in auto memory. It saves corrections, but it is local to one machine and has no evidence, no confidence, and no pruning. SAGE-Code must be strong where auto memory is weak: knowledge that a team shares in git, rules with evidence, rules that apply only to the applicable files, and proof that a rule helps.

**Goals**

1. A learned rule reaches Claude with no skill invocation and no model call.
2. A rule about `src/auth/` costs no context in a session that does not read `src/auth/`.
3. SAGE-Code does not edit the user's `CLAUDE.md`.
4. The meta-evaluator knows, for each rule, the sessions in which the rule was in context.

**Not in this design.** Reflection that always runs, the `claude plugin eval` suite, and transcript context for corrections. Each gets its own design.

## Facts verified in a real session

A probe with Claude Code v2.1.274 (`claude --plugin-dir`, non-interactive mode) confirmed:

- A plugin hook receives `InstructionsLoaded`, also with the `-p` flag.
- Rule files in a subdirectory (`.claude/rules/sage/`) load.
- A rule with no `paths:` loads at the start. The event has `load_reason: "session_start"`.
- A rule with `paths: ["src/auth/**"]` did not load when Claude read `docs/a.md`. It loaded when Claude read `src/auth/login.ts`. The event had `load_reason: "path_glob_match"`, `globs`, and `trigger_file_path`.

From the documentation: block-level HTML comments in instruction files are removed before the content goes into Claude's context. A plugin `bin/` directory is on the `PATH` of the Bash tool.

## Architecture

```
.sage/knowledge/*.md            source of truth (heuristics + metadata)
        │
        │  bin/sage-publish-rules        (deterministic script, no model)
        ▼
.claude/rules/sage/<rule-id>.md  one file per heuristic, rule text only
        │
        │  Claude Code loads the file (at start, or on a path match)
        ▼
InstructionsLoaded hook ──► rule_loaded event in .sage/events/session-<id>.jsonl
        │
        │  bin/sage-exposure             (deterministic script, no model)
        ▼
.sage/meta/exposure.json ──► meta-evaluator agent
```

Each unit has one purpose:

| Unit | Purpose | Input | Output |
|---|---|---|---|
| Reflector agent | Extract heuristics, now with `Paths` | Session event log | Knowledge entries |
| `bin/sage-publish-rules` | Make rule files agree with the knowledge files | `.sage/knowledge/*.md`, config | `.claude/rules/sage/*.md` |
| `on-instructions-loaded.sh` | Record rule loads | Hook stdin JSON | `rule_loaded` events |
| `bin/sage-exposure` | Aggregate exposure for each rule | `.sage/events/*.jsonl` | `.sage/meta/exposure.json` |
| Meta-evaluator agent | Score rules with exposure data | Knowledge, `exposure.json`, scores | Scores, demotions, prunes |

## Knowledge entry: the `Paths` field

`.sage/knowledge/*.md` stays the source of truth. Each entry gets one new optional field:

```markdown
### NEVER use md5 for password hashing
- **Confidence:** low (1 observation)
- **Scope:** project
- **Paths:** src/auth/**, src/middleware/*.ts
- **Rule:** Use bcrypt for password hashing. md5 is not safe for passwords.
- **Evidence:** sessions a1b2c3
- **Added:** 2026-09-17
- **Last seen:** 2026-09-17
```

Rules for the field:

- The value is a list of glob patterns, separated by commas. Patterns are relative to the project root.
- The reflector fills `Paths` from the `file_path` values of the tool events near the correction or failure. Event file paths are absolute. The reflector makes them relative with the `cwd` value of the `session_start` event.
- The reflector prefers a directory pattern (`src/auth/**`) to a single file. It uses at most 5 patterns.
- A heuristic that is not specific to files (for example a commit message convention) has no `Paths` field. It loads in each session.
- When the reflector merges a new observation into an existing entry, it adds new patterns to `Paths`. A merge never makes the scope narrower. If the list would have more than 5 patterns, the reflector replaces patterns with one wider pattern that covers them (for example, `src/auth/login.ts` and `src/auth/token.ts` become `src/auth/**`). The curator obeys the same limit when it merges duplicate entries.
- If one of two merged entries has no `Paths` field, the merged entry has no `Paths` field. It applies to all files.

## `bin/sage-publish-rules`

A bash script with a Python 3 body, in the same style as the hook scripts. It has no file extension, so that Claude can run it as a bare command.

**Usage:** `sage-publish-rules [project-dir]`. The project directory comes from the argument, then `SAGE_PROJECT_DIR`, then `CLAUDE_PROJECT_DIR`, then the current directory. The script exits with 0 and no output if `.sage/` does not exist.

**Procedure**

1. Read `publish_min_confidence` from `.sage/meta/config.json`. The default is `low`. The order is `low` < `medium` < `high`.
2. Parse each knowledge file. An entry starts at a `### ` heading and ends at the next `### ` heading or the end of the file. Fields have the form `- **Name:** value`. A `Rule` value can continue on indented lines. The parser ignores fields that it does not know.
3. Skip an entry that has no `Rule` field, or whose confidence is below the minimum.
4. Compute the rule ID (see below).
5. Write `.claude/rules/sage/<rule-id>.md`. Write the file only if its content changes, so that git status stays clean.
6. Delete each `*.md` file in `.claude/rules/sage/` that has no matching entry. SAGE-Code owns this directory.
7. Remove the old managed section from `CLAUDE.md` and `.claude/CLAUDE.md` (see Migration).
8. Print one summary line: `sage-publish-rules: 12 published (3 written, 9 unchanged), 1 removed`.

**Rule ID.** `<category>-<slug>`.

- The category comes from the file name: `pitfalls` → `pitfall`, `strategies` → `strategy`, `preferences` → `preference`, `architecture` → `architecture`, `conventions` → `convention`.
- The slug is the heading in lower case. Each run of characters that are not `a-z` or `0-9` becomes one `-`. Leading and trailing `-` are removed. The slug is cut to 60 characters.
- If two entries give the same ID, the second gets the suffix `-2`, the third `-3`, in file order.
- This is the same ID that the meta-evaluator uses in `scores.json`.

**Rule file format**

```markdown
---
paths:
  - "src/auth/**"
  - "src/middleware/*.ts"
---
<!-- Generated by sage-code from .sage/knowledge/pitfalls.md. Do not edit this file. Edit the knowledge entry. -->

# NEVER use md5 for password hashing

Use bcrypt for password hashing. md5 is not safe for passwords.
```

- An entry with no `Paths` field gets no frontmatter.
- Claude Code removes the HTML comment before the content goes into context. The metadata (confidence, evidence, dates) is not in the file.

**Path validation.** The script drops a pattern that is empty, is absolute, or contains `..`. If an entry had a `Paths` field but no valid pattern remains, the script publishes the rule with no frontmatter and prints a warning to stderr. A rule that loads in each session is visible in the git diff. A rule that disappears is not.

## Migration from `CLAUDE.md`

The curator of 0.2.0 wrote a managed section into `CLAUDE.md`. The publish script removes it one time:

- It looks in `CLAUDE.md` and `.claude/CLAUDE.md` in the project root.
- It removes the text from the `## Sage Learnings` heading to the `<!-- End sage-code managed section -->` marker, only if the start marker (`<!-- Auto-managed by sage-code plugin.`) and the end marker are both there.
- It changes no other text, except the blank lines directly next to the removed section (so that no run of blank lines stays there). If the markers are not both there, it changes nothing.

The knowledge-curator agent loses its task "Update CLAUDE.md".

## Replay layer changes

**`sage-replay` skill.** The scoring phase goes away. The skill keeps two tasks:

1. Process pending reflections (at most 3 logs, never the log of the current session). After the reflector finishes, run `sage-publish-rules`.
2. Tell the user if meta-evaluation is due.

**`sage-reflect` and `sage-meta` skills.** Each runs `sage-publish-rules` after its agents finish. `sage-meta` runs `sage-exposure` before it dispatches the meta-evaluator. The `allowed-tools` lists get `Bash(sage-publish-rules *)` and `Bash(sage-exposure *)`.

The skills call the scripts as bare commands, with the project directory as the argument: `sage-publish-rules "${CLAUDE_PROJECT_DIR}"`. `CLAUDE_PROJECT_DIR` is not an environment variable of the Bash tool, so the skill content uses the placeholder, which Claude Code substitutes. The implementation must confirm in a real run that `bin/` is on `PATH` with `--plugin-dir`. If it is not, the skills use `"${CLAUDE_PLUGIN_ROOT}/bin/sage-publish-rules"`.

**SessionStart hook.** The `additionalContext` text changes. The hook states facts only, and only when Claude has a task:

- the number of session logs that are pending reflection, if more than 0
- that meta-evaluation is due, if `sessions_since_eval >= meta_eval_interval_sessions`

If the two conditions are false, the hook prints nothing. Published rules need no notice, because Claude Code loads them.

**Configuration.** New key `publish_min_confidence` (default `"low"`). The keys `replay_max_heuristics`, `replay_max_tokens`, and `promote_score_threshold` go away from the template. A project that has them in its `config.json` keeps them; nothing reads them.

**Why the default is `low`.** A correction is most useful the next time. Path scope limits the noise. The rule files are in git, so each new rule appears in a diff for review. All rules go through one channel, so the exposure data covers all rules. A team that wants a higher bar sets `medium`.

## Exposure capture

**Hook.** A new entry in `hooks/hooks.json`:

```json
"InstructionsLoaded": [
  {
    "matcher": "session_start|path_glob_match|nested_traversal|include",
    "hooks": [
      {
        "type": "command",
        "command": "bash",
        "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/on-instructions-loaded.sh"]
      }
    ]
  }
]
```

The matcher runs against `load_reason`. It leaves out `compact`, which would count one rule two times in one session. Claude Code runs this event asynchronously and ignores the hook output.

**Script `on-instructions-loaded.sh`.** It reads the stdin JSON and does this:

1. Exit if `.sage/events/` does not exist.
2. Exit if `file_path` is not a `*.md` file directly in `<project>/.claude/rules/sage/`.
3. Append one event to `.sage/events/session-<session_id>.jsonl`. **Create the log if it does not exist.**

```json
{"ts": "2026-09-17T10:31:15Z", "type": "rule_loaded", "rule_id": "pitfall-never-use-md5-for-password-hashing", "load_reason": "path_glob_match", "trigger_file": "src/auth/login.ts"}
```

`rule_id` is the file name with no extension. `trigger_file` is relative to the project root when possible, and is empty for `session_start` loads.

**Race with SessionStart.** Rules with no `paths:` load at the start of the session, at the same time as the SessionStart hook runs. The other capture hooks exit when the log does not exist. This hook must not, or it loses those loads. Thus:

- `on-instructions-loaded.sh` creates the log if necessary.
- `on-session-start.sh` no longer uses "the log is empty or missing" to find a new session. It uses "the log has no `session_start` event".
- The `session_start` event is no longer always the first line of a log. No reader depends on the order.

**Session summary.** The `session_end` summary gets `rules_loaded`: the number of different rule IDs that loaded in the session.

## `bin/sage-exposure`

A deterministic aggregator. Agents do not read tens of JSONL logs.

**Usage:** `sage-exposure [project-dir]`. It reads each `.sage/events/session-*.jsonl` and writes `.sage/meta/exposure.json`:

```json
{
  "generated": "2026-09-17T12:00:00Z",
  "sessions_total": 14,
  "rules": {
    "pitfall-never-use-md5-for-password-hashing": {
      "sessions_loaded": 5,
      "sessions_not_loaded": 9,
      "first_loaded": "2026-09-01T09:00:00Z",
      "last_loaded": "2026-09-16T14:20:00Z",
      "always_loaded": false,
      "corrections_per_session_loaded": 0.2,
      "corrections_per_session_not_loaded": 0.67,
      "errors_per_session_loaded": 1.0,
      "errors_per_session_not_loaded": 1.4,
      "recent_loaded_sessions": [
        {
          "session_id": "a1b2c3",
          "trigger_files": ["src/auth/login.ts"],
          "corrections": ["no, use bcrypt instead of md5"],
          "failed_commands": ["npm test"]
        }
      ]
    }
  }
}
```

- A session counts only if it has a `session_start` event. A session that has at least one `rule_loaded` event for the rule counts as loaded.
- Sessions before `first_loaded` do not count as "not loaded". The rule did not exist then, so they are not a control group.
- `always_loaded` is true when all `load_reason` values for the rule are `session_start`.
- An error is a `tool_outcome` event with `success: false`. A correction is a `correction` event.
- `recent_loaded_sessions` holds at most the 10 most recent loaded sessions, with at most 5 correction excerpts and 5 failed commands each. It lets the evaluator decide if a correction is about the rule.
- `exposure.json` is a derived file. `.sage/.gitignore` gets the line `meta/exposure.json`.

## Meta-evaluator changes

The agent reads `exposure.json` in place of the raw event logs.

**Scoring with exposure**

- **Path-scoped rule, loaded in 3 sessions or more:** compare the loaded sessions with the not-loaded sessions. Read `recent_loaded_sessions`. A correction on the topic of the rule, in a session where the rule was in context, is strong evidence against the rule: the rule was there and did not help, or it is wrong.
- **Path-scoped rule, loaded in fewer than 3 sessions:** not sufficient data. Keep the score. Do not demote or prune.
- **Rule with `always_loaded: true`:** there is no control group. Use the before-and-after method of the 0.2.0 design.

The score rubric (1.0 to 0.0), the smoothing (`0.7 * old + 0.3 * new`), the limit of 0.3 per evaluation, and the grace period stay.

**Actions.** PROMOTE goes away, because a rule is published from the start. DEMOTE and PRUNE stay.

**Staleness (curator).** In 0.2.0 a rule was stale when `Last seen` was older than `stale_days`. This pruned a rule that worked, because a rule that works causes no new corrections. The new condition: a rule is stale when `Last seen` is older than `stale_days` **and** `last_loaded` is older than `stale_days` or the rule never loaded. A rule that loads and causes no corrections stays. A rule with `always_loaded: true` loads in each session, so it is never stale. Only its score can prune it.

## `sage-status` changes

"Promoted to CLAUDE.md: N" becomes:

```
Published rules: 12 (9 path-scoped, 3 always loaded)
```

The count comes from the files in `.claude/rules/sage/`. A file with `paths:` frontmatter is path-scoped.

## Error handling

- Each hook and script exits with 0 and no output when `.sage/` does not exist. SAGE-Code must not break a session.
- A knowledge entry that the parser cannot read is skipped, with a warning on stderr. The other entries are published.
- An event log line that is not JSON is skipped (as in `on-session-end.sh` now).
- `sage-publish-rules` runs the same way each time. A second run with no change to the knowledge writes nothing.

## Testing

**bats, `test-sage-publish-rules.bats`**

- publishes one file for each entry, with the correct rule ID
- writes `paths:` frontmatter from the `Paths` field, and no frontmatter when the field is absent
- reads a `Rule` value that continues on a second line
- keeps confidence, evidence, and dates out of the rule file
- obeys `publish_min_confidence`
- gives the suffix `-2` to the second of two equal IDs
- deletes the file of a pruned entry, and no file outside `.claude/rules/sage/`
- drops absolute and `..` patterns, and publishes with a warning if none remain
- writes nothing on a second run (file modification times do not change)
- removes the `CLAUDE.md` managed section when the two markers are there, and changes nothing when one is absent
- exits with 0 when `.sage/` does not exist

**bats, `test-on-instructions-loaded.bats`**

- records a `rule_loaded` event for a sage rule file, with `rule_id`, `load_reason`, and a relative `trigger_file`
- ignores `CLAUDE.md`, a rule file outside `sage/`, and a file in a subdirectory of `sage/`
- creates the event log when it does not exist
- exits with 0 when `.sage/` does not exist

**bats, `test-sage-exposure.bats`**

- counts loaded and not-loaded sessions, and leaves out sessions before `first_loaded`
- sets `always_loaded`
- computes corrections for each session in the two groups
- caps `recent_loaded_sessions`
- skips a bad JSON line

**bats, changes to existing tests**

- `on-session-start`: a log that has only a `rule_loaded` event still gets a `session_start` event and one session count; the context text appears only when a reflection is pending or meta-evaluation is due
- `on-session-end`: the summary has `rules_loaded`
- `test_helper.bash`: new builder `instructions_loaded_payload <file_path> [load_reason] [trigger_file_path]`

**Real run.** In a scratch git project with `claude --plugin-dir ./sage-code`: put one path-scoped entry and one general entry into `.sage/knowledge/`, run `sage-publish-rules`, start a session that reads a matching file, and confirm that the session log has two `rule_loaded` events with the correct reasons. Then run `sage-exposure` and read `exposure.json`.

## Documentation

- Root README: architecture text for Layers 4 and 5, the "How it works" list, the lifecycle diagram ("Promoted to CLAUDE.md" goes away; rules are published from the start), the `.claude/rules/sage/` directory in "Project data", and the configuration table.
- Plugin README and CHANGELOG (0.3.0, with a migration note for the `CLAUDE.md` section).
- A note at the top of the 2026-04-15 spec that points to this document for Layers 4 and 5.
- `plugin.json` version 0.3.0.

## Changes from the final review (2026-09-17)

A whole-branch review after implementation confirmed seven faults with experiments. The design changed as follows. Where this section and a section above disagree, this section is correct.

**The scripts own the rule ID.** An agent never computes a rule ID from a heading. The slug cut at 60 characters, the `-2` suffix, and the punctuation rule made the ID of an agent disagree with the ID of the script, and the curator then saw a rule that works as "never loaded". `sage-exposure` now writes one entry for each rule file in `.claude/rules/sage/`, also for a rule that never loaded, with these new keys: `heading` (the `# ` line of the rule file; `null` for a rule that has events but no file) and `published`. The agents find the entry whose `heading` is the heading of the knowledge entry and whose key starts with the category. The key of that entry is the ID in `scores.json`.

**Staleness needs exposure history.** The event logs are personal, so an upgrade, a new install, or a new clone has no history. `sage-exposure` writes the top-level key `exposure_since`: the start of the oldest complete session that has a `rule_loaded` event, or `null`. The curator does not prune for staleness when `exposure.json` is absent, when `exposure_since` is `null`, or when it is more recent than `stale_days` ago. An entry that is not published uses "Last seen" only. `sage-meta` runs `sage-publish-rules` before `sage-exposure`, and again after the curator. `sage-replay` always runs `sage-publish-rules`.

**Only active sessions are compared.** A session with no activity cannot load a path-scoped rule, so empty sessions made each path-scoped rule look bad (equal true rates gave 1.0 against 0.14). A session is active when it has a `tool_outcome`, `correction`, or `positive_signal` event. The four `*_per_session_*` numbers use active sessions only. New keys: `active_sessions_loaded` and `active_sessions_not_loaded` for each rule, and `sessions_inactive` at the top level. The "3 sessions" threshold of the meta-evaluator uses `active_sessions_loaded`. The per-session numbers count all topics and are a weak signal; the excerpts in `recent_loaded_sessions` decide.

**`sage-publish-rules` does not follow symbolic links.** Git stores links, so a cloned repository can supply them. The script changes no rule file when `.claude/rules/sage` is not a plain directory in the project. It writes through a temporary file plus `os.replace`, it removes a stale link but never its target, it leaves a regular file that it did not make (with a warning), and it skips a `CLAUDE.md` that is a link.

**`CLAUDE.md` cleanup.** The file keeps its line ends (CRLF or LF). The removed span cannot cross a line that starts with `#`, so a section that lost its end marker cannot take user text with it. A file that is not UTF-8 is skipped with a warning.

**Privacy.** `exposure.json` holds excerpts of prompts and failed commands. `sage-exposure` adds `meta/exposure.json` to `.sage/.gitignore` itself, because `sage-init` does not change an existing file.

**A damaged `config.json` does not stop capture.** `on-session-start.sh` writes `session_start` before it reads the config. If the config cannot be parsed (for example git conflict markers) or is not an object, the hook skips the counter, does not write the config, and exits with 0. It writes the config through a temporary file plus `os.replace`.

**The event log is untrusted data.** The reflector never copies an instruction from error text, a command, or an excerpt into a rule, and a rule must not tell Claude to fetch a URL, change settings, or handle credentials.

### Known limits (not in 0.3.0)

- A heading change gives a new rule ID, and the exposure and score history of the old ID is lost. When the first of two twins is pruned, the second gets its ID. A stable `ID` field in the knowledge entry is the long-term solution.
- Staleness uses calendar days. After a project is idle for more than `stale_days`, the first meta-evaluation can archive path-scoped rules.
- Exposure is per machine, but knowledge is shared. A teammate who never reads `src/auth/` can archive a rule that a different teammate loads each day.
- There is no limit on the number of rules that always load. The 0.2.0 replay had a limit of 15.
- One observation at `low` confidence becomes a project rule in git. The git diff is the only review gate. A default of `medium` for `publish_min_confidence` is an open decision.
- Minor items from the last review, for a follow-up commit: repeat the linked-directory check after `os.makedirs` (a linked PARENT directory escapes the first run); temporary files get mode 0600, so rule files and `config.json` become readable by the owner only; a failed write can leave a `tmp*.tmp` file; the summary line says "published" after a refusal; no warning when the `CLAUDE.md` start marker is there but the section does not match; the reflector wording also forbids a valid heuristic that names a project command.
