---
name: sage-reflect
description: Manually trigger SAGE-Code reflection on the current session's events. Use when you want to process learnings without waiting for the next session.
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
  - Bash(git diff *)
  - Bash(rm .sage/events/*)
  - Bash(sage-publish-rules *)
---

# Manual Reflection Trigger

Force reflection on the current session's events immediately.

## Process

1. Use the event log of the current session: `.sage/events/session-${CLAUDE_SESSION_ID}.jsonl`. If it does not exist, use the most recent log in `.sage/events/`
2. Dispatch the `sage-code:reflector` subagent with the event log path
3. Run `sage-publish-rules "${CLAUDE_PROJECT_DIR}"` to make the rule files in `.claude/rules/sage/` agree with the knowledge files
4. Run `git diff -- .sage/knowledge/` to see what changed
5. Summarize new/updated heuristics
6. Remove the `.unprocessed` marker of that log if present (`rm .sage/events/<name>.unprocessed`)

Output:
```
## Sage Reflection Complete
**New heuristics:** ...
**Updated heuristics:** ...
**Rule files:** {summary line of sage-publish-rules}
```
