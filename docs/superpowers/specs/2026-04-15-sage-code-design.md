# SAGE-Code: Self-Adapting Generative Engine for Code

**Date:** 2026-04-15  
**Status:** Design  
**Author:** Claude + Umar  

## Overview

SAGE-Code is a Claude Code plugin that makes Claude autonomously learn and improve within each project it works on. It captures session events, reflects on outcomes, builds project-scoped knowledge, and periodically evaluates its own rules — all without user intervention.

**Goals (all three simultaneously):**
1. **Task performance** — Learn from mistakes and successes, produce better code over time
2. **User adaptation** — Learn the user's preferences, coding style, and workflow
3. **Project expertise** — Build deep knowledge of each project's architecture, patterns, and conventions

**Design principles:**
- Fully autonomous — no user approval needed for learning
- Project-scoped — each project accumulates its own knowledge
- Distributable — ships as a Claude Code plugin installable from a GitHub marketplace
- Scientifically grounded — architecture based on published research with empirical evidence

## Scientific Foundations

| Paper | Contribution to SAGE-Code | Key Result |
|---|---|---|
| [Reflexion (NeurIPS 2023)](https://arxiv.org/abs/2303.11366) | Core reflect→evaluate→store loop architecture | 91% HumanEval pass@1 (vs 80% GPT-4 baseline) |
| [Contextual Experience Replay (ACL 2025)](https://arxiv.org/abs/2506.06698) | Selective retrieval from memory buffer based on task context | +51% improvement over GPT-4o baseline |
| [Self-Reflection in LLM Agents (2024)](https://arxiv.org/abs/2405.06682) | Empirical validation that self-reflection significantly improves problem-solving | p < 0.001 statistical significance |
| [SAGE: Self-evolving Agents (2025)](https://dl.acm.org/doi/10.1016/j.neucom.2025.130470) | Memory-augmented reflective architecture with scoring | 2.26x performance gains |
| [Intrinsic Metacognitive Learning (ICML 2025)](https://openreview.net/forum?id=4KhDd0Ozqe) | Meta-evaluation layer that evaluates whether reflections actually help | Position: necessary for true self-improvement |
| [Experiential Reflective Learning (2025)](https://arxiv.org/pdf/2603.24639) | Heuristic generation from task outcomes, stored in persistent pool | +7.8% over ReAct baseline on Gaia2 |

**Prior art (Claude Code specific):**

| Project | What it does | What SAGE-Code improves on |
|---|---|---|
| [claude-meta](https://github.com/aviadr1/claude-meta) | Meta-rules for writing rules, user-triggered reflection | Automates the reflection trigger; adds meta-evaluation |
| [claude-reflect](https://github.com/BayramAnnakov/claude-reflect) | Hook-based correction capture, manual /reflect review | Removes the manual gate; adds experience replay and scoring |
| [self-learning-claude](https://github.com/reshadat/self-learning-claude) | JSON playbook with categorized patterns | Adds confidence scoring, pruning, and metacognitive evaluation |
| [Learnings.md pattern](https://www.mindstudio.ai/blog/self-learning-claude-code-skill-learnings-md) | Structured markdown learning file | Adds selective replay, automated reflection, and lifecycle management |

## Architecture

SAGE-Code is a five-layer system, each layer building on the one below:

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

## Plugin Structure

```
sage-code/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── skills/
│   ├── sage-replay/
│   │   └── SKILL.md             # SessionStart: loads relevant knowledge
│   ├── sage-reflect/
│   │   └── SKILL.md             # Session-end reflection subagent
│   ├── sage-meta/
│   │   └── SKILL.md             # Periodic meta-learning evaluator
│   └── sage-status/
│       └── SKILL.md             # User-facing: show what sage has learned
├── agents/
│   ├── reflector.md             # Subagent: analyzes sessions, extracts heuristics
│   ├── meta-evaluator.md        # Subagent: evaluates rule effectiveness
│   └── knowledge-curator.md     # Subagent: organizes/deduplicates knowledge
├── hooks/
│   ├── hooks.json               # Hook definitions for all lifecycle events
│   └── scripts/
│       ├── on-session-start.sh  # Load context, initialize event log
│       ├── on-tool-use.sh       # Capture tool outcomes to event log
│       ├── on-correction.sh     # Detect user corrections via prompt analysis
│       └── on-session-end.sh    # Write session summary, mark as unprocessed
├── templates/
│   ├── knowledge-schema.json    # Schema for knowledge entries
│   └── event-log-schema.json   # Schema for captured events
├── bin/
│   └── sage-init.sh             # Bootstrap sage data directory in a project
└── README.md
```

## Per-Project Data Directory

Created on first session via `sage-init.sh`:

```
.sage/
├── events/
│   └── session-<id>.jsonl       # Event log per session (raw captures)
├── knowledge/
│   ├── pitfalls.md              # Errors/anti-patterns to avoid
│   ├── strategies.md            # Proven effective approaches
│   ├── preferences.md           # User style/preference learnings
│   ├── architecture.md          # Project architecture knowledge
│   └── conventions.md           # Coding conventions discovered
├── meta/
│   ├── scores.json              # Heuristic effectiveness scores
│   ├── history.json             # Meta-evaluation history
│   ├── archive.md               # Pruned heuristics (audit trail)
│   └── config.json              # Sage configuration
└── README.md                    # Auto-generated summary
```

**Git strategy:**
- `.sage/knowledge/` — committed (shared team knowledge)
- `.sage/events/` — gitignored (personal, ephemeral session logs)
- `.sage/meta/` — committed (shared scores and history)
- `.sage/README.md` — committed (human-readable summary)

---

## Layer 1: Capture

Passively observes session events through Claude Code hooks and writes structured JSONL logs.

### Hooks

| Hook Event | What it captures | Script | Blocking? |
|---|---|---|---|
| `SessionStart` | Initializes event log, records git branch/diff/recent commits. Returns a `systemMessage` that triggers the `sage-replay` skill. | `on-session-start.sh` | No (async) |
| `PostToolUse` | Tool name, input summary, outcome, duration. Filters to state-changing tools (Write, Edit, Bash, Agent) | `on-tool-use.sh` | No (async) |
| `UserPromptSubmit` | Regex-based correction detection ("no", "don't", "actually", "instead", "wrong") and positive signals ("perfect", "exactly", "yes that's right") | `on-correction.sh` | No (async) |
| `Stop` | Session summary: total tools, errors, files modified, duration. Marks session event log as "unprocessed". | `on-session-end.sh` | No (async) |

All hooks run with `async: true` and complete in <100ms (append-only file writes).

### How Reflection is Triggered

Shell hooks cannot dispatch subagents directly. Instead, SAGE-Code uses **deferred reflection**: the `Stop` hook marks the session's event log as unprocessed (writes a `.unprocessed` marker file). On the NEXT session start, the `sage-replay` skill checks for unprocessed event logs and runs reflection on them BEFORE performing replay. This means there is a one-session delay between an event and its reflection — an acceptable trade-off for architectural simplicity.

The `SessionStart` hook returns a `systemMessage` containing `"[sage] Run /sage-replay to initialize"`, which triggers the sage-replay skill automatically.

### Event Log Format

`.sage/events/session-<id>.jsonl`:

```jsonl
{"ts":"2026-04-15T22:30:00Z","type":"session_start","branch":"main","cwd":"/project","recent_commits":["fix auth","add tests"]}
{"ts":"2026-04-15T22:31:15Z","type":"tool_outcome","tool":"Edit","file":"src/api.ts","success":true}
{"ts":"2026-04-15T22:32:00Z","type":"correction","signal":"negative","pattern":"no_use_x","raw":"no, use async/await instead of .then()"}
{"ts":"2026-04-15T22:45:00Z","type":"tool_outcome","tool":"Bash","cmd":"npm test","success":false,"error":"3 tests failed"}
{"ts":"2026-04-15T22:50:00Z","type":"positive_signal","raw":"perfect, exactly what I wanted"}
{"ts":"2026-04-15T22:55:00Z","type":"session_end","tools_used":12,"errors":1,"files_modified":3,"duration_s":1500}
```

### Design Decisions

- **JSONL over JSON** — append-only, crash-safe, no full-file parsing to add an entry
- **Regex capture, AI validation later** — fast regex in hooks catches corrections with false positives acceptable; the Reflection layer filters with full reasoning. Follows claude-reflect's proven hybrid approach.
- **Tool filtering** — skip read-only tools (Read, Glob, Grep) to reduce noise; capture state-changing tools (Write, Edit, Bash, Agent)
- **Async execution** — hooks never block the user's session

---

## Layer 2: Reflection

A subagent that runs at session end, transforming raw event logs into generalized knowledge.

### Trigger

Reflection is **deferred** — it runs at the START of the next session, not at the end of the current one. The `sage-replay` skill checks for `.unprocessed` marker files in `.sage/events/` and dispatches the `reflector` subagent for each unprocessed session before performing knowledge replay. After reflection completes, the marker file is removed.

This design avoids the impossible task of having a shell hook dispatch a subagent, and ensures that reflection never delays the user's current session ending.

### Reflector Subagent

- **Model:** `sonnet` (structured extraction, not creative reasoning — cost-efficient)
- **Context:** `fork` (isolated, doesn't pollute main conversation)
- **Tools:** Read, Write, Edit, Glob, Grep only (no Bash, no external access)
- **Inputs:** Current session event log + existing knowledge files + project CLAUDE.md

### Reflection Process

Mirrors the Reflexion (Actor → Evaluator → Self-Reflection → Memory) pipeline:

**Step 1: PARSE**
Read the session event log. Identify corrections, failures, successes, and patterns.

**Step 2: EVALUATE**
For each correction/failure: What went wrong? Was this a repeat of a known pitfall? Is this project-specific or general?
For each success/positive signal: What approach was used? Is this worth codifying?

**Step 3: ABSTRACT**
Generalize specific instances into reusable heuristics.
Example: "user corrected .then() to async/await" → "ALWAYS use async/await over .then() chains in this project"

Each heuristic gets:
- **id:** deterministic slug from category + heading, e.g. `pitfall-never-fs-readsync`, `preference-async-await-over-then`
- **category:** pitfall | strategy | preference | architecture | convention
- **confidence:** low (1 observation) | medium (2-3) | high (4+)
- **scope:** project | language | universal
- **evidence:** list of session IDs where observed

**Step 4: MERGE**
Compare new heuristics against existing knowledge files:
- Duplicate → increment confidence, add evidence
- Contradictory → keep higher-confidence version (evidence-weighted)
- Novel → append with confidence=low

**Step 5: WRITE**
Update relevant `.sage/knowledge/*.md` files.

### Conflict Resolution

When a new observation contradicts an existing rule:
- Existing rule has higher confidence → keep it, log contradiction as data point
- Equal confidence → demote both one level, flag for meta-evaluation
- New observation has more recent/frequent evidence → promote new, demote old

### Skip Conditions

The reflector does nothing if:
- Session had fewer than 5 tool uses (not enough signal)
- Session had no corrections, no failures, and no notable patterns
- Selective generation outperforms exhaustive capture (per Experiential Reflective Learning paper)

---

## Layer 3: Knowledge

Structured, persistent markdown files that accumulate across sessions.

### Knowledge Files

| File | Category | Contents |
|---|---|---|
| `pitfalls.md` | Errors to avoid | Anti-patterns, things that break, common mistakes |
| `strategies.md` | Proven approaches | Techniques that worked, preferred solutions |
| `preferences.md` | User style | Communication style, code style opinions, workflow preferences |
| `architecture.md` | Project structure | Architectural decisions, module boundaries, data flow |
| `conventions.md` | Coding standards | Naming, formatting, project-specific patterns |

### Entry Format

```markdown
### NEVER use relative imports across module boundaries
- **Confidence:** medium (3 observations)
- **Scope:** project
- **Rule:** Use path aliases (`@/modules/auth`) instead of relative paths
  (`../../modules/auth`) when importing across module boundaries. Relative
  imports within the same module are fine.
- **Evidence:** sessions a1b2c3, d4e5f6, g7h8i9
- **Added:** 2026-04-10
- **Last seen:** 2026-04-15
```

### Why Markdown

- Claude reads/writes markdown with higher fidelity than JSON
- Human-readable — users can inspect what sage has learned
- Grep-friendly — easy to search for specific rules
- Git-diffable — changes are meaningful in PRs

### Knowledge Lifecycle

```
Captured (1 obs, low) → Reinforced (2-3, medium) → Established (4+, high)
                                                          │
                                                    Promoted to CLAUDE.md
                                                          │
                          Demoted (contradicted) ◄────────┘
                                │
                          Pruned (30+ days stale, or score < 0.2)
```

### CLAUDE.md Promotion

When a heuristic reaches `confidence: high` AND `score > 0.7`, the reflector appends it to the project's CLAUDE.md under a managed section:

```markdown
## Sage Learnings
<!-- Auto-managed by sage-code plugin. Do not edit below this line. -->
- ALWAYS use async/await over .then() chains in this project
- NEVER use relative imports across module boundaries — use @/ aliases
<!-- End sage-code managed section -->
```

### Size Management

Knowledge files capped at 100 entries each. The `knowledge-curator` subagent handles overflow by:
- Merging redundant entries
- Removing entries with no evidence in 30+ days
- Consolidating related entries into broader rules
- Archiving pruned entries to `.sage/meta/archive.md`

---

## Layer 4: Replay

Selective retrieval that injects only relevant knowledge at session start.

### Trigger

The `SessionStart` hook returns a `systemMessage` that triggers the `sage-replay` skill. The skill runs in two phases:

1. **Reflect phase:** Check for `.unprocessed` marker files in `.sage/events/`. For each, dispatch the `reflector` subagent to process the event log and update knowledge files. Remove the marker after processing.
2. **Replay phase:** Score existing knowledge against the current session's context and inject relevant heuristics.

This two-phase design ensures reflection from the previous session completes before replay loads potentially-updated knowledge.

### Context Detection

Signals gathered by `on-session-start.sh`:
- Git diff (recently changed files)
- Git branch name
- Current directory
- Recent commit messages

### Relevance Scoring

Each heuristic scored against current context:

| Signal | Score |
|---|---|
| File/directory path match with git diff | +3 |
| Pitfall category (always higher priority) | +2 |
| Reinforced recently (last 7 days) | +1 |
| High confidence | +1 |

### Injection

Top 10-15 heuristics formatted as concise bullets, injected via skill output:

```
## Sage Context for This Session
Based on your current work (branch: feature/auth, files: src/auth/*.ts):
- NEVER store JWT tokens in localStorage (high confidence)
- ALWAYS validate token expiry server-side (medium)
- User prefers async/await over .then() chains (high)
- Auth middleware expects req.user set by passport (medium)
```

### Token Budget

Hard-capped at 500 tokens. If more heuristics are relevant, only highest-scoring ones included.

### Cold Start

First session in a new project: initialize `.sage/` directory, output "Sage: No prior learnings for this project. I'll begin learning from this session."

---

## Layer 5: Meta-Learning

Periodic self-evaluation that assesses whether accumulated knowledge is actually helping.

### Trigger

Piggybacks on the `sage-replay` skill at session start. After the reflect and replay phases complete, sage-replay checks `.sage/meta/config.json` for `last_meta_eval` timestamp and `sessions_since_eval` counter. If either threshold is exceeded (10 sessions or 1 day), it dispatches the `sage-meta` skill which spawns the `meta-evaluator` subagent. The counter increments on every session start regardless.

### Meta-Evaluator Subagent

- **Model:** `sonnet`
- **Inputs:** Knowledge files, recent event logs, score history

### Evaluation Process

**Step 1: OUTCOME CORRELATION**
For each heuristic: Was it replayed? Did sessions where it was present show fewer corrections/failures in its domain?

**Step 2: SCORING**
Each heuristic scored in `.sage/meta/scores.json`:

```json
{
  "heuristic_id": "pitfall-never-fs-readsync",
  "score": 0.8,
  "observations": 12,
  "trend": "stable",
  "last_eval": "2026-04-15"
}
```

**Step 3: ACTION**

| Score | Trend | Action |
|---|---|---|
| > 0.7 | any | PROMOTE to CLAUDE.md |
| 0.4 - 0.7 | any | RETAIN, continue monitoring |
| < 0.4 | declining | DEMOTE (drop confidence, remove from CLAUDE.md) |
| < 0.2 | any (10+ obs) | PRUNE (remove, archive) |

**Step 4: CURATION**
Dispatch `knowledge-curator` to merge duplicates, consolidate, enforce size limits, update `.sage/README.md`.

### Safeguards

- Pruning requires 10+ observations minimum
- Demotion requires 5+ observations minimum
- New rules (< 7 days old) get a grace period — cannot be pruned
- Archived heuristics preserved in `.sage/meta/archive.md` for audit trail

### Why This Layer Matters

The ICML 2025 metacognition paper argues this is the missing piece in all current self-improving agent systems. Without it:
- **Rule rot:** Outdated conventions persist and actively harm
- **Overfitting:** One-time quirks become permanent rules
- **Bloat:** Unbounded growth dilutes signal
- **Contradiction:** Conflicting rules from different time periods coexist

---

## User Interface

One user-invocable skill: `/sage-status`

```
## Sage Status for /Users/you/project

Sessions analyzed: 34
Heuristics learned: 47 (12 high, 20 medium, 15 low)
Promoted to CLAUDE.md: 8
Pruned (ineffective): 3
Last meta-evaluation: 2 days ago

### Top Learnings (by confidence)
1. [high] ALWAYS use async/await over .then() chains
2. [high] NEVER commit .env files — use .env.example
3. [high] Run npm test --bail before git commit

### Recently Learned
1. [low] Prefer named exports over default exports
2. [low] Use zod for API input validation
```

---

## Configuration

`.sage/meta/config.json` — all thresholds are tunable:

```json
{
  "version": "1.0.0",
  "min_session_tools_for_reflection": 5,
  "max_knowledge_entries_per_file": 100,
  "replay_max_heuristics": 15,
  "replay_max_tokens": 500,
  "meta_eval_interval_days": 1,
  "meta_eval_interval_sessions": 10,
  "prune_min_observations": 10,
  "prune_score_threshold": 0.2,
  "promote_score_threshold": 0.7,
  "stale_days": 30,
  "new_rule_grace_days": 7,
  "reflector_model": "sonnet",
  "meta_evaluator_model": "sonnet"
}
```

---

## Edge Cases

| Scenario | Handling |
|---|---|
| First session in project | Create `.sage/`, cold-start message, no reflection |
| Very short session (< 5 tools) | Reflector skips — insufficient signal |
| User contradicts a sage rule | Correction captured, heuristic demoted, eventually pruned if repeated |
| Conflicting team members | Evidence-weighted consensus; preferences scoped individually |
| Massive project (1000+ files) | Relevance scoring filters to contextual heuristics; knowledge capped at 100/file |
| No git repo | Degrades gracefully — skip git context, use directory structure/mtimes |
| Hook script failure | Async + error swallowing — never blocks user session; errors logged |
| Token budget exceeded | Hard cap at 500 tokens for replay injection |

---

## Complete Data Flow

```
Session N starts
    │
    ▼
[SessionStart hook] ──► Initialize event log, gather git context
    │                    Return systemMessage to trigger sage-replay
    ▼
[sage-replay skill: REFLECT PHASE]
    │  Check for .unprocessed event logs from Session N-1
    │  If found: dispatch reflector subagent
    │     reflector ──► Parse → Evaluate → Abstract → Merge → Write
    │                   Update .sage/knowledge/*.md
    │                   Remove .unprocessed marker
    ▼
[sage-replay skill: REPLAY PHASE]
    │  Score knowledge vs current git context
    │  Inject top 10-15 relevant heuristics (≤500 tokens)
    ▼
User works normally
    │
    ├──[UserPromptSubmit hook] ──► Detect corrections/praise
    ├──[PostToolUse hook] ──► Log tool outcomes
    │
    ▼
[Stop hook] ──► Write session summary
                Mark event log as .unprocessed
                (reflection deferred to Session N+1 start)

═══════════════════════════════════════════
Periodic (every 10 sessions or 1 day):

[sage-meta skill] ──► Dispatch meta-evaluator subagent
    │                  Score heuristics against outcomes
    │                  Promote / Demote / Prune
    ▼
[knowledge-curator subagent] ──► Deduplicate, consolidate
                                  Update CLAUDE.md managed section
                                  Update .sage/README.md
```
