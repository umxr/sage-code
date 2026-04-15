---
name: sage-reflect
description: Manually trigger SAGE-Code reflection on the current session's events. Use when you want to process learnings without waiting for the next session.
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
---

# Manual Reflection Trigger

Force reflection on the current session's events immediately.

## Process

1. Find the most recent event log in `.sage/events/` (by modification time)
2. Dispatch the `reflector` subagent with the event log path
3. Read git diff on `.sage/knowledge/` to see what changed
4. Summarize new/updated heuristics
5. Remove `.unprocessed` marker if present

Output:
```
## Sage Reflection Complete
**New heuristics:** ...
**Updated heuristics:** ...
```
