---
name: sage-status
description: Show what SAGE-Code has learned about this project. Displays heuristic counts, confidence breakdown, top learnings, and recent additions.
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
---

# SAGE-Code Status Report

Generate a status report of what SAGE has learned about this project.

## Process

1. Read `.sage/meta/config.json`
2. Count `.jsonl` files in `.sage/events/`
3. Read all `.sage/knowledge/` files, extract confidence and category per entry
4. Read `.sage/meta/scores.json` and `.sage/meta/history.json`
5. Count the `*.md` files in `.claude/rules/sage/`. A file that starts with `---` has `paths:` frontmatter and is path-scoped; the others load in each session

## Output

```
## Sage Status for {project directory}

Sessions analyzed: {count}
Heuristics learned: {total} ({high} high, {medium} medium, {low} low)
Published rules: {count} ({path-scoped} path-scoped, {always} always loaded)
Pruned (ineffective): {count in archive}
Last meta-evaluation: {date or "never"}

### Top Learnings (by confidence)
1. [high] {heading}
...

### Recently Learned (last 7 days)
1. [low] {heading} ({category})
...

### Category Breakdown
- Pitfalls: {count}
- Strategies: {count}
- Preferences: {count}
- Architecture: {count}
- Conventions: {count}
```

If `.sage/` doesn't exist: "Sage has not been initialized in this project yet."
