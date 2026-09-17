---
name: sage-meta
description: Run SAGE-Code meta-evaluation to score heuristic effectiveness and prune ineffective rules. Triggers automatically every 10 sessions or daily.
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
  - Bash(sage-exposure *)
  - Bash(sage-publish-rules *)
---

# Meta-Evaluation Orchestrator

1. Run `sage-exposure "${CLAUDE_PROJECT_DIR}"`. It writes `.sage/meta/exposure.json`: for each rule, the sessions in which Claude Code loaded it
2. Dispatch the `sage-code:meta-evaluator` subagent
3. After evaluation, dispatch the `sage-code:knowledge-curator` subagent
4. Run `sage-publish-rules "${CLAUDE_PROJECT_DIR}"`. It deletes the rule files of pruned heuristics and updates the others
5. Report results:

```
## Sage Meta-Evaluation Complete
**Evaluated:** N heuristics
**Demoted:** N (confidence lowered)
**Pruned:** N (removed, archived)
**Average score:** 0.XX
**Rule files:** {summary line of sage-publish-rules}
```
