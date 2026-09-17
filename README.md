<p align="center">
  <img src="assets/logo.svg" alt="SAGE-Code Logo" width="200" />
</p>

<h1 align="center">sage-code</h1>

<p align="center">
  <strong>Self-Adapting Generative Engine for Code</strong><br/>
  A Claude Code plugin that makes Claude autonomously learn and improve within each project.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License" /></a>
  <a href="CHANGELOG.md"><img src="https://img.shields.io/badge/version-0.3.0-blue.svg" alt="Version" /></a>
</p>

---

Grounded in peer-reviewed research: [Reflexion (NeurIPS 2023)](https://arxiv.org/abs/2303.11366), [Contextual Experience Replay (ACL 2025)](https://arxiv.org/abs/2506.06698), [SAGE (Neurocomputing 2025)](https://dl.acm.org/doi/10.1016/j.neucom.2025.130470), and the [ICML 2025 position on metacognitive learning](https://openreview.net/forum?id=4KhDd0Ozqe).

## What it does

SAGE-Code observes your Claude Code sessions and builds project-specific knowledge over time:

- **Captures** corrections, tool outcomes, and patterns during sessions via hooks
- **Reflects** on what worked and what didn't, extracting reusable heuristics via subagents
- **Replays** knowledge as native Claude Code rules: each heuristic is a file in `.claude/rules/sage/`, and a rule about `src/auth/` loads only when Claude reads a file in `src/auth/`
- **Self-evaluates** with measured exposure: it records which rules were in context in which session, compares sessions with and without each rule, and prunes the rules that do not help

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
| `/sage-code:sage-status` | View what SAGE has learned about your project |
| `/sage-code:sage-reflect` | Manually trigger reflection on current session |
| `/sage-code:sage-meta` | Run meta-evaluation to score and prune heuristics |

Plugin skills are namespaced by the plugin name. The short forms (`/sage-status`, `/sage-reflect`, `/sage-meta`) also work when no other command uses the same name.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Layer 5: META-LEARNING (Self-Evaluation)           │
│  Measures which rules were loaded in which session  │
│  Demotes and prunes rules that do not help          │
├─────────────────────────────────────────────────────┤
│  Layer 4: REPLAY (Native Rules)                     │
│  Publishes each heuristic to .claude/rules/sage/    │
│  Claude Code loads a rule when a matching file is   │
│  read                                               │
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

1. **SessionStart hook** initializes the event log, gathers git context, and tells Claude (through `additionalContext`) what there is to replay
2. **PostToolUse and PostToolUseFailure hooks** capture the outcomes of state-changing tools (Write, Edit, Bash, ...). Claude Code reports a failed tool call as `PostToolUseFailure`, so SAGE does not guess failures from the output text
3. **UserPromptSubmit hook** detects corrections ("no, use X instead") and praise ("perfect, exactly")
4. **SessionEnd hook** writes a session summary and marks the log for deferred reflection
5. **sage-replay skill** (next session) sends the reflector to the pending session logs. The reflector gives each heuristic a `Paths` field with the files where it applies
6. **`sage-publish-rules`** (a script, no model call) writes one rule file per heuristic to `.claude/rules/sage/`. Claude Code loads these files itself. SAGE-Code does not edit your `CLAUDE.md`
7. **InstructionsLoaded hook** records each rule that Claude Code loads, with the file that triggered the load
8. **Meta-evaluator** (every 10 sessions) reads the exposure data from `sage-exposure`, scores each rule, and demotes or prunes the rules that do not help

All hooks read their input as JSON from stdin, as the [Claude Code hooks reference](https://code.claude.com/docs/en/hooks) specifies. The capture hooks run with `async: true`, so they do not slow down the session.

## Project data

SAGE creates a `.sage/` directory and a `.claude/rules/sage/` directory in your project:

```
.sage/
├── knowledge/        # Learned heuristics with evidence (committed to git)
│   ├── pitfalls.md   # Errors and anti-patterns to avoid
│   ├── strategies.md # Proven effective approaches
│   ├── preferences.md# User style and workflow preferences
│   ├── architecture.md# Project structure knowledge
│   └── conventions.md# Coding conventions
├── events/           # Session logs (gitignored, personal)
├── meta/             # Scores, config, history (committed)
└── README.md         # Auto-generated summary

.claude/rules/sage/   # One rule file per heuristic (committed to git)
└── pitfall-never-use-md5-for-password-hashing.md
```

Do not edit the files in `.claude/rules/sage/`. They are made from `.sage/knowledge/`. Edit the knowledge entry, then run `/sage-code:sage-reflect` or `sage-publish-rules`. Because the rule files are in git, each new rule appears in a diff for review.

## Knowledge lifecycle

Heuristics progress through confidence levels based on evidence:

```
Captured (1 obs, low) → Reinforced (2-3, medium) → Established (4+, high)
        │                        │                          │
        └────────── published to .claude/rules/sage/ ───────┘
                                 │
                   Demoted (corrections continue while the rule is loaded)
                                 │
                   Pruned (score < 0.2, or no evidence and no load in 30 days)
```

Each heuristic is published from its first observation. Set `publish_min_confidence` to `medium` to publish a heuristic only after a second observation.

## Configuration

Edit `.sage/meta/config.json` to tune thresholds:

| Setting | Default | Description |
|---|---|---|
| `publish_min_confidence` | `low` | Lowest confidence that is published as a rule file (`low`, `medium`, or `high`) |
| `meta_eval_interval_sessions` | 10 | Sessions between meta-evaluations |
| `prune_score_threshold` | 0.2 | Score below which rules are pruned |
| `stale_days` | 30 | Days with no new evidence and no load before pruning |
| `new_rule_grace_days` | 7 | Grace period before new rules can be pruned |

## Development

Requires a current version of Claude Code (tested with v2.1.274), Python 3, and [bats-core](https://github.com/bats-core/bats-core) for the tests.

```bash
bash sage-code/tests/run-all.sh          # run the test suite
claude plugin validate . --strict        # validate the marketplace manifest
claude plugin validate ./sage-code --strict   # validate the plugin
claude --plugin-dir ./sage-code          # try the plugin without installing it
```

Run `/reload-plugins` in a session to pick up changes to the plugin files.

## Design docs

- [Design spec](docs/superpowers/specs/2026-04-15-sage-code-design.md) — Full architecture with scientific foundations
- [Native rules and measured exposure](docs/superpowers/specs/2026-09-17-native-rules-and-exposure-design.md) — Layers 4 and 5 since 0.3.0
- [Implementation plan](docs/superpowers/plans/2026-04-15-sage-code-plan.md) — Task-by-task build plan

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Security

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.

## License

[MIT](LICENSE)
