# sage-code

Self-Adapting Generative Engine for Code — a Claude Code plugin that makes Claude autonomously learn and improve within each project.

## What it does

SAGE-Code observes your Claude Code sessions and builds project-specific knowledge over time:

- **Captures** corrections, tool outcomes, and patterns during sessions
- **Reflects** on what worked and what didn't, extracting reusable heuristics
- **Replays** relevant knowledge at the start of each session
- **Self-evaluates** whether its learned rules actually help, pruning ineffective ones

Everything is fully autonomous — no manual intervention needed.

## Installation

Enable the plugin in your Claude Code settings:

```json
{
  "enabledPlugins": {
    "sage-code@your-marketplace": true
  }
}
```

On your first session in any project, SAGE will automatically initialize a `.sage/` directory and begin learning.

## Commands

- `/sage-status` — View what SAGE has learned about your project
- `/sage-reflect` — Manually trigger reflection on current session

## How it works

1. **Hooks** passively capture session events (corrections, tool outcomes, successes)
2. **Reflector** analyzes events and extracts generalized heuristics with confidence scores
3. **Knowledge files** accumulate in `.sage/knowledge/` as categorized markdown
4. **Replay** injects only relevant heuristics at session start based on git context
5. **Meta-evaluator** periodically scores rules and prunes ineffective ones

## Project data

SAGE creates a `.sage/` directory in your project:

- `knowledge/` — Learned heuristics (committed to git, shared with team)
- `events/` — Raw session logs (gitignored, personal)
- `meta/` — Evaluation scores and config (committed to git)

## Configuration

Edit `.sage/meta/config.json` to tune thresholds. See the spec for all options.
