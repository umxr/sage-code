---
name: sage-replay
description: Processes pending SAGE-Code reflections from earlier sessions and publishes the learned rules. Runs at session start when the SessionStart context says that session logs are not reflected on yet.
user-invocable: false
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
  - Bash(rm .sage/events/*)
  - Bash(sage-publish-rules *)
---

# SAGE-Code Pending Reflections

Claude Code loads the learned rules itself, from `.claude/rules/sage/`. This skill does not load knowledge. It turns the logs of earlier sessions into knowledge.

## Phase 1: Deferred Reflection

1. Use Glob to find files matching `.sage/events/*.unprocessed`
2. For each (max 3), but never the log of the current session (`session-${CLAUDE_SESSION_ID}`):
   a. Read the corresponding `.jsonl` file
   b. Check if it has ≥5 tool_outcome events AND ≥1 correction/failure/positive_signal
   c. If sufficient: dispatch the `sage-code:reflector` subagent with the event log path
   d. Delete the `.unprocessed` marker after processing (`rm .sage/events/<name>.unprocessed`)

## Phase 2: Publish

If a reflector ran, run this command to make the rule files agree with the knowledge files:

```bash
sage-publish-rules "${CLAUDE_PROJECT_DIR}"
```

Report the summary line that the command prints.

## Phase 3: Meta-Evaluation Check

Read `.sage/meta/config.json`. If `sessions_since_eval` >= `meta_eval_interval_sessions`, output:
"[sage] Meta-evaluation due. Run /sage-code:sage-meta to evaluate heuristic effectiveness."
