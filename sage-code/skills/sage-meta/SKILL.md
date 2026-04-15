---
name: sage-meta
description: Run SAGE-Code meta-evaluation to score heuristic effectiveness and prune ineffective rules. Triggers automatically every 10 sessions or daily.
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
---

# Meta-Evaluation Orchestrator

1. Dispatch the `meta-evaluator` subagent
2. After evaluation, dispatch the `knowledge-curator` subagent
3. Report results:

```
## Sage Meta-Evaluation Complete
**Evaluated:** N heuristics
**Promoted:** N (moved to CLAUDE.md)
**Demoted:** N (confidence lowered)
**Pruned:** N (removed, archived)
**Average score:** 0.XX
```
