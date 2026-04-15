# sage-code

Self-Adapting Generative Engine for Code — a Claude Code plugin that makes Claude autonomously learn and improve within each project.

Grounded in peer-reviewed research: [Reflexion (NeurIPS 2023)](https://arxiv.org/abs/2303.11366), [Contextual Experience Replay (ACL 2025)](https://arxiv.org/abs/2506.06698), [SAGE (Neurocomputing 2025)](https://dl.acm.org/doi/10.1016/j.neucom.2025.130470), and the [ICML 2025 position on metacognitive learning](https://openreview.net/forum?id=4KhDd0Ozqe).

## What it does

SAGE-Code observes your Claude Code sessions and builds project-specific knowledge over time:

- **Captures** corrections, tool outcomes, and patterns during sessions via hooks
- **Reflects** on what worked and what didn't, extracting reusable heuristics via subagents
- **Replays** relevant knowledge at the start of each session based on git context
- **Self-evaluates** whether its learned rules actually help, pruning ineffective ones

Everything is fully autonomous — no manual intervention needed.

## Installation

```bash
/plugin marketplace add umxr/sage-code
/plugin install sage-code@sage-code-marketplace
```

Or add to your `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "sage-code-marketplace": {
      "source": { "source": "github", "repo": "umxr/sage-code" }
    }
  },
  "enabledPlugins": {
    "sage-code@sage-code-marketplace": true
  }
}
```

On your first session in any project, SAGE will automatically initialize a `.sage/` directory and begin learning.

## Commands

| Command | Description |
|---|---|
| `/sage-status` | View what SAGE has learned about your project |
| `/sage-reflect` | Manually trigger reflection on current session |
| `/sage-meta` | Run meta-evaluation to score and prune heuristics |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Layer 5: META-LEARNING (Self-Evaluation)           │
│  Periodic subagent evaluates rule effectiveness     │
│  Promotes, demotes, prunes heuristics               │
├─────────────────────────────────────────────────────┤
│  Layer 4: REPLAY (Session Start)                    │
│  Scores knowledge against current task context      │
│  Injects top 10-15 relevant heuristics              │
├─────────────────────────────────────────────────────┤
│  Layer 3: KNOWLEDGE (Evolving Files)                │
│  Structured markdown files with confidence scores   │
│  Categories: pitfalls, strategies, preferences...   │
├─────────────────────────────────────────────────────┤
│  Layer 2: REFLECTION (Subagent)                     │
│  Analyzes session events at session end             │
│  Extracts and generalizes heuristics                │
├─────────────────────────────────────────────────────┤
│  Layer 1: CAPTURE (Hooks)                           │
│  Passively observes session events                  │
│  Writes structured JSONL event log                  │
└─────────────────────────────────────────────────────┘
```

## How it works

1. **SessionStart hook** initializes the event log, gathers git context, and triggers the replay skill
2. **PostToolUse hook** captures outcomes of state-changing tools (Write, Edit, Bash)
3. **UserPromptSubmit hook** detects corrections ("no, use X instead") and praise ("perfect, exactly")
4. **Stop hook** writes a session summary and marks the log for deferred reflection
5. **sage-replay skill** (next session) processes pending reflections, then injects relevant heuristics
6. **Meta-evaluator** (every 10 sessions) scores rules against outcomes and prunes ineffective ones

## Project data

SAGE creates a `.sage/` directory in your project:

```
.sage/
├── knowledge/        # Learned heuristics (committed to git)
│   ├── pitfalls.md   # Errors and anti-patterns to avoid
│   ├── strategies.md # Proven effective approaches
│   ├── preferences.md# User style and workflow preferences
│   ├── architecture.md# Project structure knowledge
│   └── conventions.md# Coding conventions
├── events/           # Session logs (gitignored, personal)
├── meta/             # Scores, config, history (committed)
└── README.md         # Auto-generated summary
```

## Knowledge lifecycle

Heuristics progress through confidence levels based on evidence:

```
Captured (1 obs, low) → Reinforced (2-3, medium) → Established (4+, high)
                                                          │
                                                    Promoted to CLAUDE.md
                                                          │
                          Demoted (contradicted) ◄────────┘
                                │
                          Pruned (stale or score < 0.2)
```

High-confidence rules are automatically promoted to your project's `CLAUDE.md`, where Claude reads them at every session start.

## Configuration

Edit `.sage/meta/config.json` to tune thresholds:

| Setting | Default | Description |
|---|---|---|
| `replay_max_heuristics` | 15 | Max heuristics injected per session |
| `meta_eval_interval_sessions` | 10 | Sessions between meta-evaluations |
| `promote_score_threshold` | 0.7 | Score needed for CLAUDE.md promotion |
| `prune_score_threshold` | 0.2 | Score below which rules are pruned |
| `stale_days` | 30 | Days without evidence before pruning |
| `new_rule_grace_days` | 7 | Grace period before new rules can be pruned |

## Running tests

```bash
bash sage-code/tests/run-all.sh
```

## Design docs

- [Design spec](docs/superpowers/specs/2026-04-15-sage-code-design.md) — Full architecture with scientific foundations
- [Implementation plan](docs/superpowers/plans/2026-04-15-sage-code-plan.md) — Task-by-task build plan

## License

MIT
