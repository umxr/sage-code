---
name: sage-replay
description: Initializes SAGE-Code for the current session. Processes pending reflections from previous sessions, then loads relevant project knowledge based on current git context. Runs automatically at session start.
user-invocable: false
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
---

# SAGE-Code Session Initializer

You are the SAGE-Code replay system. You run at the start of each session to:
1. Process any pending reflections from previous sessions
2. Load relevant project knowledge for the current session
3. Check if meta-evaluation is due

## Phase 1: Deferred Reflection

1. Use Glob to find files matching `.sage/events/*.unprocessed`
2. For each (max 3):
   a. Read the corresponding `.jsonl` file
   b. Check if it has ≥5 tool_outcome events AND ≥1 correction/failure/positive_signal
   c. If sufficient: dispatch the `reflector` subagent with the event log path
   d. Delete the `.unprocessed` marker after processing

## Phase 2: Knowledge Replay

1. Read `.sage/meta/config.json` for `replay_max_heuristics` (default: 15)
2. Read the current session's event log for git context (branch, diff_files)
3. Read ALL knowledge files in `.sage/knowledge/`
4. Score each heuristic:
   - +3 if Rule text mentions files from diff_files
   - +2 if category is "pitfall"
   - +1 if "Last seen" within 7 days
   - +1 if confidence is "high"
   - +1 if Rule text matches branch name keywords
5. Output top N as concise bullets:

```
## Sage Context for This Session
Based on your current work (branch: {branch}, files: {diff files}):
- {heading} ({confidence})
- ...
```

If empty: "Sage: No prior learnings for this project. I'll begin learning from this session."

## Phase 3: Meta-Evaluation Check

Check if `sessions_since_eval` >= threshold OR `last_meta_eval` is old enough.
If due: output "[sage] Meta-evaluation due. Run /sage-meta to evaluate heuristic effectiveness."
