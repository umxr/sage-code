<p align="center">
  <img src="../assets/logo.svg" alt="SAGE-Code Logo" width="160" />
</p>

# sage-code

Self-Adapting Generative Engine for Code — a Claude Code plugin that makes Claude autonomously learn and improve within each project.

## What it does

SAGE-Code observes your Claude Code sessions and builds project-specific knowledge over time:

- **Captures** corrections, tool outcomes, and patterns during sessions
- **Reflects** on what worked and what didn't, extracting reusable heuristics
- **Replays** knowledge as native Claude Code rules in `.claude/rules/sage/`; a path-scoped rule loads only when Claude reads a matching file
- **Self-evaluates** with measured exposure (which rules loaded in which session), pruning the rules that do not help

Everything is fully autonomous — no manual intervention needed.

## Installation

```bash
/plugin marketplace add umxr/sage-code
/plugin install sage-code@sage-code-marketplace
```

On your first session in any project, SAGE will automatically initialize a `.sage/` directory and begin learning.

## Commands

- `/sage-code:sage-status` — View what SAGE has learned about your project
- `/sage-code:sage-reflect` — Manually trigger reflection on current session
- `/sage-code:sage-meta` — Run meta-evaluation to score and prune heuristics

## How it works

1. **Hooks** passively capture session events (corrections, tool outcomes, successes)
2. **Reflector** analyzes events and extracts generalized heuristics with confidence scores
3. **Knowledge files** accumulate in `.sage/knowledge/` as categorized markdown
4. **Rules** — `sage-publish-rules` writes one file per heuristic to `.claude/rules/sage/`; Claude Code loads a path-scoped rule only when Claude reads a matching file
5. **Meta-evaluator** periodically scores rules with measured exposure (which rules loaded in which session) and prunes ineffective ones

## Project data

SAGE creates a `.sage/` directory in your project:

- `knowledge/` — Learned heuristics (committed to git, shared with team)
- `events/` — Raw session logs (gitignored, personal)
- `meta/` — Evaluation scores and config (committed to git)
- `.claude/rules/sage/` — One rule file per heuristic (committed to git, made from `knowledge/`; do not edit)

## Configuration

Edit `.sage/meta/config.json` to tune thresholds. See the spec for all options.
