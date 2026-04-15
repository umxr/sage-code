# SAGE-Code Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that autonomously learns and improves per-project through session capture, reflection, knowledge accumulation, contextual replay, and meta-evaluation.

**Architecture:** Five-layer plugin: shell hook scripts capture session events into JSONL logs; a reflector subagent extracts heuristics into categorized markdown knowledge files; a replay skill injects relevant context at session start; a meta-evaluator periodically scores and prunes rules. All orchestrated through Claude Code's plugin system (hooks.json, SKILL.md, agent definitions).

**Tech Stack:** Bash (hook scripts), Markdown (skills, agents, knowledge), JSON (config, scores, event logs), Claude Code Plugin API

**Spec:** `docs/superpowers/specs/2026-04-15-sage-code-design.md`

---

## File Map

### Plugin scaffold
- Create: `sage-code/.claude-plugin/plugin.json` — Plugin manifest
- Create: `sage-code/README.md` — User-facing documentation

### Layer 1: Capture (hooks)
- Create: `sage-code/hooks/hooks.json` — Hook event definitions
- Create: `sage-code/hooks/scripts/on-session-start.sh` — Initialize event log + git context
- Create: `sage-code/hooks/scripts/on-tool-use.sh` — Capture state-changing tool outcomes
- Create: `sage-code/hooks/scripts/on-correction.sh` — Regex-based correction/praise detection
- Create: `sage-code/hooks/scripts/on-session-end.sh` — Write session summary + mark unprocessed

### Layer 1.5: Bootstrap
- Create: `sage-code/bin/sage-init.sh` — Bootstrap `.sage/` directory in a project
- Create: `sage-code/templates/config-default.json` — Default configuration template
- Create: `sage-code/templates/gitignore-template` — .gitignore for .sage/events/

### Layer 2: Reflection (agents)
- Create: `sage-code/agents/reflector.md` — Reflector subagent definition

### Layer 3: Knowledge curation (agents)
- Create: `sage-code/agents/knowledge-curator.md` — Knowledge curator subagent definition

### Layer 5: Meta-learning (agents)
- Create: `sage-code/agents/meta-evaluator.md` — Meta-evaluator subagent definition

### Layer 4: Replay (skills)
- Create: `sage-code/skills/sage-replay/SKILL.md` — Two-phase: reflect then replay

### Layer 5: Meta-learning (skills)
- Create: `sage-code/skills/sage-meta/SKILL.md` — Meta-evaluation orchestrator

### User interface (skills)
- Create: `sage-code/skills/sage-status/SKILL.md` — Show learned heuristics
- Create: `sage-code/skills/sage-reflect/SKILL.md` — Manual reflection trigger

### Testing
- Create: `sage-code/tests/test-hooks.sh` — Integration tests for all hook scripts
- Create: `sage-code/tests/fixtures/sample-events.jsonl` — Sample event log for testing

---

## Task 1: Plugin Scaffold

**Files:**
- Create: `sage-code/.claude-plugin/plugin.json`
- Create: `sage-code/README.md`

- [ ] **Step 1: Create plugin manifest**

```json
{
  "name": "sage-code",
  "description": "Self-Adapting Generative Engine — autonomous learning plugin that captures session events, reflects on outcomes, builds project-scoped knowledge, and self-evaluates its own rules",
  "version": "0.1.0",
  "author": {
    "name": "SAGE-Code Contributors"
  },
  "repository": "https://github.com/sage-code/sage-code",
  "license": "MIT"
}
```

Write this to `sage-code/.claude-plugin/plugin.json`.

- [ ] **Step 2: Create README**

```markdown
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
```

Write this to `sage-code/README.md`.

- [ ] **Step 3: Commit**

```bash
git add sage-code/.claude-plugin/plugin.json sage-code/README.md
git commit -m "feat: add plugin scaffold with manifest and README"
```

---

## Task 2: Bootstrap Script + Templates

**Files:**
- Create: `sage-code/bin/sage-init.sh`
- Create: `sage-code/templates/config-default.json`
- Create: `sage-code/templates/gitignore-template`

- [ ] **Step 1: Write the test for sage-init.sh**

```bash
#!/usr/bin/env bash
# sage-code/tests/test-sage-init.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

echo "=== Test: sage-init.sh creates .sage/ directory structure ==="

# Run init in temp directory
SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"

# Verify directory structure
PASS=true
for dir in ".sage" ".sage/events" ".sage/knowledge" ".sage/meta"; do
  if [ ! -d "$TEST_DIR/$dir" ]; then
    echo "FAIL: $dir not created"
    PASS=false
  fi
done

# Verify knowledge files exist
for f in pitfalls.md strategies.md preferences.md architecture.md conventions.md; do
  if [ ! -f "$TEST_DIR/.sage/knowledge/$f" ]; then
    echo "FAIL: .sage/knowledge/$f not created"
    PASS=false
  fi
done

# Verify config
if [ ! -f "$TEST_DIR/.sage/meta/config.json" ]; then
  echo "FAIL: .sage/meta/config.json not created"
  PASS=false
fi

# Verify gitignore
if [ ! -f "$TEST_DIR/.sage/.gitignore" ]; then
  echo "FAIL: .sage/.gitignore not created"
  PASS=false
fi

# Verify README
if [ ! -f "$TEST_DIR/.sage/README.md" ]; then
  echo "FAIL: .sage/README.md not created"
  PASS=false
fi

# Verify idempotency — running again should not error or overwrite
SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
if [ $? -ne 0 ]; then
  echo "FAIL: sage-init.sh not idempotent"
  PASS=false
fi

if $PASS; then
  echo "PASS: All sage-init.sh checks passed"
else
  echo "FAIL: Some checks failed"
  exit 1
fi
```

Write this to `sage-code/tests/test-sage-init.sh` and make it executable with `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x sage-code/tests/test-sage-init.sh
bash sage-code/tests/test-sage-init.sh
```

Expected: FAIL — `sage-init.sh` does not exist yet.

- [ ] **Step 3: Create the default config template**

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
  "meta_evaluator_model": "sonnet",
  "sessions_since_eval": 0,
  "last_meta_eval": null
}
```

Write to `sage-code/templates/config-default.json`.

- [ ] **Step 4: Create the gitignore template**

```
# Session event logs are personal and ephemeral
events/
```

Write to `sage-code/templates/gitignore-template`.

- [ ] **Step 5: Write sage-init.sh**

```bash
#!/usr/bin/env bash
# sage-code/bin/sage-init.sh
# Bootstrap the .sage/ directory structure in a project.
# Idempotent — safe to run multiple times.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${SAGE_PROJECT_DIR:-$(pwd)}"
SAGE_DIR="$PROJECT_DIR/.sage"

# Create directory structure
mkdir -p "$SAGE_DIR/events"
mkdir -p "$SAGE_DIR/knowledge"
mkdir -p "$SAGE_DIR/meta"

# Create knowledge files (only if they don't exist)
for category in pitfalls strategies preferences architecture conventions; do
  KNOWLEDGE_FILE="$SAGE_DIR/knowledge/$category.md"
  if [ ! -f "$KNOWLEDGE_FILE" ]; then
    cat > "$KNOWLEDGE_FILE" << MKEOF
# ${category^}

<!-- Auto-managed by sage-code. Manual edits are preserved during merges. -->
MKEOF
  fi
done

# Copy default config (only if it doesn't exist)
if [ ! -f "$SAGE_DIR/meta/config.json" ]; then
  cp "$SCRIPT_DIR/templates/config-default.json" "$SAGE_DIR/meta/config.json"
fi

# Initialize scores.json (only if it doesn't exist)
if [ ! -f "$SAGE_DIR/meta/scores.json" ]; then
  echo '[]' > "$SAGE_DIR/meta/scores.json"
fi

# Initialize history.json (only if it doesn't exist)
if [ ! -f "$SAGE_DIR/meta/history.json" ]; then
  echo '[]' > "$SAGE_DIR/meta/history.json"
fi

# Create archive.md (only if it doesn't exist)
if [ ! -f "$SAGE_DIR/meta/archive.md" ]; then
  cat > "$SAGE_DIR/meta/archive.md" << 'MKEOF'
# Archived Heuristics

<!-- Pruned heuristics are preserved here for audit trail. -->
MKEOF
fi

# Copy gitignore (only if it doesn't exist)
if [ ! -f "$SAGE_DIR/.gitignore" ]; then
  cp "$SCRIPT_DIR/templates/gitignore-template" "$SAGE_DIR/.gitignore"
fi

# Create README (only if it doesn't exist)
if [ ! -f "$SAGE_DIR/README.md" ]; then
  cat > "$SAGE_DIR/README.md" << 'MKEOF'
# SAGE-Code Knowledge Base

This directory is managed by the [sage-code](https://github.com/sage-code/sage-code) plugin.

**Sessions analyzed:** 0
**Heuristics learned:** 0

## Knowledge Categories

- `knowledge/pitfalls.md` — Errors and anti-patterns to avoid
- `knowledge/strategies.md` — Proven effective approaches
- `knowledge/preferences.md` — User style and preferences
- `knowledge/architecture.md` — Project architecture knowledge
- `knowledge/conventions.md` — Coding conventions

## How it works

SAGE captures session events, reflects on them, and builds project-specific
knowledge that improves Claude's performance over time. See the plugin README
for details.
MKEOF
fi
```

Write to `sage-code/bin/sage-init.sh` and make executable with `chmod +x`.

- [ ] **Step 6: Run test to verify it passes**

```bash
bash sage-code/tests/test-sage-init.sh
```

Expected: PASS — all checks pass.

- [ ] **Step 7: Commit**

```bash
git add sage-code/bin/ sage-code/templates/ sage-code/tests/test-sage-init.sh
git commit -m "feat: add sage-init.sh bootstrap script with tests and templates"
```

---

## Task 3: SessionStart Hook Script

**Files:**
- Create: `sage-code/hooks/scripts/on-session-start.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# sage-code/tests/test-on-session-start.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Bootstrap .sage/ first
SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"

echo "=== Test: on-session-start.sh creates event log and returns systemMessage ==="

# Mock environment variables that hooks receive
export SAGE_PROJECT_DIR="$TEST_DIR"
export CLAUDE_SESSION_ID="test-session-001"

# Run the hook (capture stdout as the hook response)
RESPONSE=$(bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" 2>/dev/null)

# Verify event log was created
EVENT_LOG="$TEST_DIR/.sage/events/session-test-session-001.jsonl"
if [ ! -f "$EVENT_LOG" ]; then
  echo "FAIL: Event log not created at $EVENT_LOG"
  exit 1
fi

# Verify first line is session_start event
FIRST_LINE=$(head -1 "$EVENT_LOG")
if ! echo "$FIRST_LINE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['type']=='session_start'" 2>/dev/null; then
  echo "FAIL: First event is not session_start: $FIRST_LINE"
  exit 1
fi

# Verify response contains systemMessage
if ! echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'systemMessage' in d" 2>/dev/null; then
  echo "FAIL: Response does not contain systemMessage: $RESPONSE"
  exit 1
fi

echo "PASS: on-session-start.sh works correctly"
```

Write to `sage-code/tests/test-on-session-start.sh` and `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
bash sage-code/tests/test-on-session-start.sh
```

Expected: FAIL — script does not exist.

- [ ] **Step 3: Write on-session-start.sh**

```bash
#!/usr/bin/env bash
# sage-code/hooks/scripts/on-session-start.sh
# Hook: SessionStart
# Initializes the session event log with git context.
# Returns a systemMessage to trigger sage-replay.
set -euo pipefail

PROJECT_DIR="${SAGE_PROJECT_DIR:-$(pwd)}"
SAGE_DIR="$PROJECT_DIR/.sage"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Bootstrap .sage/ if it doesn't exist (first session)
if [ ! -d "$SAGE_DIR" ]; then
  bash "$SCRIPT_DIR/bin/sage-init.sh"
fi

# Ensure events directory exists
mkdir -p "$SAGE_DIR/events"

EVENT_LOG="$SAGE_DIR/events/session-${SESSION_ID}.jsonl"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Gather git context (gracefully handle non-git repos)
GIT_BRANCH=""
GIT_RECENT_COMMITS="[]"
GIT_DIFF_FILES="[]"

if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "")
  GIT_RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --oneline -5 --format='"%s"' 2>/dev/null | paste -sd, - | sed 's/^/[/;s/$/]/' || echo "[]")
  GIT_DIFF_FILES=$(git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null | head -20 | sed 's/.*/"&"/' | paste -sd, - | sed 's/^/[/;s/$/]/' || echo "[]")
fi

# Handle empty arrays
[ -z "$GIT_RECENT_COMMITS" ] && GIT_RECENT_COMMITS="[]"
[ -z "$GIT_DIFF_FILES" ] && GIT_DIFF_FILES="[]"

# Write session_start event
cat >> "$EVENT_LOG" << EVEOF
{"ts":"${TIMESTAMP}","type":"session_start","session_id":"${SESSION_ID}","branch":"${GIT_BRANCH}","cwd":"${PROJECT_DIR}","recent_commits":${GIT_RECENT_COMMITS},"diff_files":${GIT_DIFF_FILES}}
EVEOF

# Increment sessions_since_eval counter in config
if [ -f "$SAGE_DIR/meta/config.json" ]; then
  python3 -c "
import json
with open('$SAGE_DIR/meta/config.json', 'r') as f:
    config = json.load(f)
config['sessions_since_eval'] = config.get('sessions_since_eval', 0) + 1
with open('$SAGE_DIR/meta/config.json', 'w') as f:
    json.dump(config, f, indent=2)
" 2>/dev/null || true
fi

# Return systemMessage to trigger sage-replay
cat << 'HOOKEOF'
{"systemMessage":"[sage-code] Session initialized. Run /sage-replay to load project knowledge and process any pending reflections."}
HOOKEOF
```

Write to `sage-code/hooks/scripts/on-session-start.sh` and `chmod +x`.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash sage-code/tests/test-on-session-start.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add sage-code/hooks/scripts/on-session-start.sh sage-code/tests/test-on-session-start.sh
git commit -m "feat: add SessionStart hook script with event log initialization"
```

---

## Task 4: PostToolUse Hook Script

**Files:**
- Create: `sage-code/hooks/scripts/on-tool-use.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# sage-code/tests/test-on-tool-use.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"

echo "=== Test: on-tool-use.sh captures state-changing tools ==="

export SAGE_PROJECT_DIR="$TEST_DIR"
export CLAUDE_SESSION_ID="test-session-002"

EVENT_LOG="$TEST_DIR/.sage/events/session-test-session-002.jsonl"
touch "$EVENT_LOG"

# Test 1: Write tool should be captured
HOOK_INPUT='{"tool_name":"Write","tool_input":{"file_path":"src/index.ts","content":"hello"},"tool_result":"File written"}'
echo "$HOOK_INPUT" | bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 1 ]; then
  echo "FAIL: Expected 1 line after Write tool, got $LINES"
  exit 1
fi

# Test 2: Read tool should be skipped
HOOK_INPUT='{"tool_name":"Read","tool_input":{"file_path":"src/index.ts"},"tool_result":"file contents"}'
echo "$HOOK_INPUT" | bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 1 ]; then
  echo "FAIL: Read tool should have been skipped, got $LINES lines"
  exit 1
fi

# Test 3: Bash tool with failure should capture error
HOOK_INPUT='{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_result":"Error: 3 tests failed"}'
echo "$HOOK_INPUT" | bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 2 ]; then
  echo "FAIL: Expected 2 lines after Bash tool, got $LINES"
  exit 1
fi

# Verify the Bash entry has error detection
LAST_LINE=$(tail -1 "$EVENT_LOG")
if ! echo "$LAST_LINE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['success']==False" 2>/dev/null; then
  echo "FAIL: Bash error not detected as failure"
  exit 1
fi

echo "PASS: on-tool-use.sh works correctly"
```

Write to `sage-code/tests/test-on-tool-use.sh` and `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
bash sage-code/tests/test-on-tool-use.sh
```

Expected: FAIL.

- [ ] **Step 3: Write on-tool-use.sh**

```bash
#!/usr/bin/env bash
# sage-code/hooks/scripts/on-tool-use.sh
# Hook: PostToolUse
# Captures state-changing tool outcomes to the session event log.
# Reads hook input from stdin as JSON.
# Skips read-only tools (Read, Glob, Grep, Grep, WebSearch, WebFetch).
set -euo pipefail

PROJECT_DIR="${SAGE_PROJECT_DIR:-$(pwd)}"
SAGE_DIR="$PROJECT_DIR/.sage"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
EVENT_LOG="$SAGE_DIR/events/session-${SESSION_ID}.jsonl"

# Exit silently if .sage/ or event log doesn't exist
[ -d "$SAGE_DIR" ] || exit 0
[ -f "$EVENT_LOG" ] || exit 0

# Read hook input from stdin
INPUT=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Skip read-only tools
case "$TOOL_NAME" in
  Read|Glob|Grep|WebSearch|WebFetch|TodoWrite|AskUserQuestion|ListMcpResourcesTool|ReadMcpResourceTool)
    exit 0
    ;;
esac

# Skip if tool name is empty
[ -z "$TOOL_NAME" ] && exit 0

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Extract key fields and detect success/failure
python3 -c "
import json, sys, re

data = json.load(sys.stdin)
tool_name = data.get('tool_name', '')
tool_input = data.get('tool_input', {})
tool_result = str(data.get('tool_result', ''))

# Detect failure from result text
error_patterns = r'(?i)(error|fail|exception|traceback|FAIL|ERR!|fatal|denied|refused|not found)'
success = not bool(re.search(error_patterns, tool_result[:500]))

# Build event
event = {
    'ts': '$TIMESTAMP',
    'type': 'tool_outcome',
    'tool': tool_name,
    'success': success
}

# Add file path for file operations
if 'file_path' in tool_input:
    event['file'] = tool_input['file_path']
elif 'command' in tool_input:
    cmd = tool_input['command']
    event['cmd'] = cmd[:200]

# Add truncated error info if failure
if not success:
    event['error'] = tool_result[:300]

print(json.dumps(event))
" <<< "$INPUT" >> "$EVENT_LOG" 2>/dev/null || true
```

Write to `sage-code/hooks/scripts/on-tool-use.sh` and `chmod +x`.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash sage-code/tests/test-on-tool-use.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add sage-code/hooks/scripts/on-tool-use.sh sage-code/tests/test-on-tool-use.sh
git commit -m "feat: add PostToolUse hook script with tool filtering and error detection"
```

---

## Task 5: UserPromptSubmit Hook Script (Correction Detection)

**Files:**
- Create: `sage-code/hooks/scripts/on-correction.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# sage-code/tests/test-on-correction.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"

echo "=== Test: on-correction.sh detects corrections and praise ==="

export SAGE_PROJECT_DIR="$TEST_DIR"
export CLAUDE_SESSION_ID="test-session-003"

EVENT_LOG="$TEST_DIR/.sage/events/session-test-session-003.jsonl"
touch "$EVENT_LOG"

# Test 1: Negative correction should be captured
echo '{"user_input":"no, use async/await instead of .then()"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 1 ]; then
  echo "FAIL: Correction not captured, got $LINES lines"
  exit 1
fi

FIRST=$(head -1 "$EVENT_LOG")
if ! echo "$FIRST" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['signal']=='negative'" 2>/dev/null; then
  echo "FAIL: Signal should be negative"
  exit 1
fi

# Test 2: Positive signal should be captured
echo '{"user_input":"perfect, exactly what I wanted"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 2 ]; then
  echo "FAIL: Praise not captured, got $LINES lines"
  exit 1
fi

# Test 3: Normal message should NOT be captured
echo '{"user_input":"can you add a function to calculate totals?"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 2 ]; then
  echo "FAIL: Normal message should not be captured, got $LINES lines"
  exit 1
fi

echo "PASS: on-correction.sh works correctly"
```

Write to `sage-code/tests/test-on-correction.sh` and `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
bash sage-code/tests/test-on-correction.sh
```

Expected: FAIL.

- [ ] **Step 3: Write on-correction.sh**

```bash
#!/usr/bin/env bash
# sage-code/hooks/scripts/on-correction.sh
# Hook: UserPromptSubmit
# Detects user corrections and positive signals via regex patterns.
# Reads hook input from stdin as JSON with "user_input" field.
set -euo pipefail

PROJECT_DIR="${SAGE_PROJECT_DIR:-$(pwd)}"
SAGE_DIR="$PROJECT_DIR/.sage"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
EVENT_LOG="$SAGE_DIR/events/session-${SESSION_ID}.jsonl"

# Exit silently if .sage/ or event log doesn't exist
[ -d "$SAGE_DIR" ] || exit 0
[ -f "$EVENT_LOG" ] || exit 0

# Read hook input from stdin
INPUT=$(cat)

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

python3 -c "
import json, sys, re

data = json.load(sys.stdin)
user_input = data.get('user_input', '')

# Skip very short messages (likely not corrections)
if len(user_input.strip()) < 5:
    sys.exit(0)

# Negative correction patterns (start of message or after punctuation)
negative_patterns = [
    r'(?i)^no[,.\s]',
    r'(?i)^don.?t\s',
    r'(?i)^stop\s',
    r'(?i)^wrong',
    r'(?i)\bactually[,\s]',
    r'(?i)\binstead[,\s]',
    r'(?i)\bnot that\b',
    r'(?i)\buse\s+\w+\s+instead\b',
    r'(?i)^that.?s (wrong|incorrect|not right)',
    r'(?i)^never\s',
    r'(?i)^always\s',
    r'(?i)\bremember:?\s',
]

# Positive signal patterns
positive_patterns = [
    r'(?i)^(perfect|exactly|great|awesome|nice)',
    r'(?i)^yes[,!\s].*(?:right|correct|that|exactly)',
    r'(?i)that.?s (perfect|exactly|correct|right)',
    r'(?i)^good (job|work|call)',
    r'(?i)^love (it|this|that)',
]

signal = None
pattern_name = None

for p in negative_patterns:
    if re.search(p, user_input):
        signal = 'negative'
        pattern_name = p
        break

if signal is None:
    for p in positive_patterns:
        if re.search(p, user_input):
            signal = 'positive'
            pattern_name = p
            break

if signal is None:
    sys.exit(0)

event = {
    'ts': '$TIMESTAMP',
    'type': 'correction' if signal == 'negative' else 'positive_signal',
    'signal': signal,
    'raw': user_input[:500]
}

print(json.dumps(event))
" <<< "$INPUT" >> "$EVENT_LOG" 2>/dev/null || true
```

Write to `sage-code/hooks/scripts/on-correction.sh` and `chmod +x`.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash sage-code/tests/test-on-correction.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add sage-code/hooks/scripts/on-correction.sh sage-code/tests/test-on-correction.sh
git commit -m "feat: add UserPromptSubmit hook for correction and praise detection"
```

---

## Task 6: Stop Hook Script

**Files:**
- Create: `sage-code/hooks/scripts/on-session-end.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# sage-code/tests/test-on-session-end.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"

echo "=== Test: on-session-end.sh writes summary and marks unprocessed ==="

export SAGE_PROJECT_DIR="$TEST_DIR"
export CLAUDE_SESSION_ID="test-session-004"

EVENT_LOG="$TEST_DIR/.sage/events/session-test-session-004.jsonl"

# Seed with some events
cat > "$EVENT_LOG" << 'SEED'
{"ts":"2026-04-15T22:30:00Z","type":"session_start","session_id":"test-session-004","branch":"main","cwd":"/project"}
{"ts":"2026-04-15T22:31:00Z","type":"tool_outcome","tool":"Edit","file":"src/a.ts","success":true}
{"ts":"2026-04-15T22:32:00Z","type":"tool_outcome","tool":"Bash","cmd":"npm test","success":false,"error":"fail"}
{"ts":"2026-04-15T22:33:00Z","type":"correction","signal":"negative","raw":"no, use X"}
{"ts":"2026-04-15T22:34:00Z","type":"tool_outcome","tool":"Write","file":"src/b.ts","success":true}
SEED

bash "$SCRIPT_DIR/hooks/scripts/on-session-end.sh" 2>/dev/null

# Verify session_end event was appended
LAST_LINE=$(tail -1 "$EVENT_LOG")
if ! echo "$LAST_LINE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['type']=='session_end'" 2>/dev/null; then
  echo "FAIL: session_end event not written"
  exit 1
fi

# Verify summary counts
if ! echo "$LAST_LINE" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['tools_used']==3, f'tools_used={d[\"tools_used\"]}'
assert d['errors']==1, f'errors={d[\"errors\"]}'
assert d['corrections']==1, f'corrections={d[\"corrections\"]}'
assert d['files_modified']==2, f'files_modified={d[\"files_modified\"]}'
" 2>/dev/null; then
  echo "FAIL: Summary counts are wrong: $LAST_LINE"
  exit 1
fi

# Verify .unprocessed marker
if [ ! -f "$TEST_DIR/.sage/events/session-test-session-004.unprocessed" ]; then
  echo "FAIL: .unprocessed marker not created"
  exit 1
fi

echo "PASS: on-session-end.sh works correctly"
```

Write to `sage-code/tests/test-on-session-end.sh` and `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
bash sage-code/tests/test-on-session-end.sh
```

Expected: FAIL.

- [ ] **Step 3: Write on-session-end.sh**

```bash
#!/usr/bin/env bash
# sage-code/hooks/scripts/on-session-end.sh
# Hook: Stop
# Writes session summary event and marks the log as unprocessed.
set -euo pipefail

PROJECT_DIR="${SAGE_PROJECT_DIR:-$(pwd)}"
SAGE_DIR="$PROJECT_DIR/.sage"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
EVENT_LOG="$SAGE_DIR/events/session-${SESSION_ID}.jsonl"

# Exit silently if event log doesn't exist
[ -f "$EVENT_LOG" ] || exit 0

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Compute summary from event log
python3 -c "
import json, sys

events = []
with open('$EVENT_LOG', 'r') as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass

tools_used = sum(1 for e in events if e.get('type') == 'tool_outcome')
errors = sum(1 for e in events if e.get('type') == 'tool_outcome' and not e.get('success', True))
corrections = sum(1 for e in events if e.get('type') == 'correction')
positive_signals = sum(1 for e in events if e.get('type') == 'positive_signal')
files_modified = len(set(
    e.get('file', '') for e in events
    if e.get('type') == 'tool_outcome' and e.get('file') and e.get('success', True)
))

# Calculate duration from first to last event
timestamps = [e.get('ts', '') for e in events if e.get('ts')]
duration_s = 0
if len(timestamps) >= 2:
    from datetime import datetime
    try:
        t0 = datetime.fromisoformat(timestamps[0].replace('Z', '+00:00'))
        t1 = datetime.fromisoformat(timestamps[-1].replace('Z', '+00:00'))
        duration_s = int((t1 - t0).total_seconds())
    except (ValueError, TypeError):
        pass

summary = {
    'ts': '$TIMESTAMP',
    'type': 'session_end',
    'tools_used': tools_used,
    'errors': errors,
    'corrections': corrections,
    'positive_signals': positive_signals,
    'files_modified': files_modified,
    'duration_s': duration_s
}

print(json.dumps(summary))
" >> "$EVENT_LOG" 2>/dev/null || true

# Mark as unprocessed for deferred reflection
touch "$SAGE_DIR/events/session-${SESSION_ID}.unprocessed"
```

Write to `sage-code/hooks/scripts/on-session-end.sh` and `chmod +x`.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash sage-code/tests/test-on-session-end.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add sage-code/hooks/scripts/on-session-end.sh sage-code/tests/test-on-session-end.sh
git commit -m "feat: add Stop hook script with session summary and unprocessed marker"
```

---

## Task 7: Hooks Configuration

**Files:**
- Create: `sage-code/hooks/hooks.json`

- [ ] **Step 1: Write hooks.json**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "SAGE_PROJECT_DIR=\"$PWD\" CLAUDE_SESSION_ID=\"$CLAUDE_SESSION_ID\" bash \"$CLAUDE_PLUGIN_DIR/hooks/scripts/on-session-start.sh\"",
            "async": true,
            "asyncTimeout": 5000
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo '$TOOL_INPUT' | SAGE_PROJECT_DIR=\"$PWD\" CLAUDE_SESSION_ID=\"$CLAUDE_SESSION_ID\" bash \"$CLAUDE_PLUGIN_DIR/hooks/scripts/on-tool-use.sh\"",
            "async": true,
            "asyncTimeout": 3000
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo '$USER_INPUT' | SAGE_PROJECT_DIR=\"$PWD\" CLAUDE_SESSION_ID=\"$CLAUDE_SESSION_ID\" bash \"$CLAUDE_PLUGIN_DIR/hooks/scripts/on-correction.sh\"",
            "async": true,
            "asyncTimeout": 3000
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "SAGE_PROJECT_DIR=\"$PWD\" CLAUDE_SESSION_ID=\"$CLAUDE_SESSION_ID\" bash \"$CLAUDE_PLUGIN_DIR/hooks/scripts/on-session-end.sh\"",
            "async": true,
            "asyncTimeout": 5000
          }
        ]
      }
    ]
  }
}
```

Write to `sage-code/hooks/hooks.json`.

- [ ] **Step 2: Commit**

```bash
git add sage-code/hooks/hooks.json
git commit -m "feat: add hooks.json with all lifecycle hook definitions"
```

---

## Task 8: Reflector Subagent

**Files:**
- Create: `sage-code/agents/reflector.md`

- [ ] **Step 1: Write the reflector agent definition**

```markdown
---
description: Analyzes session event logs and extracts generalized heuristics into knowledge files. Dispatched by sage-replay when unprocessed session logs are found.
model: sonnet
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Reflector Agent

You are the SAGE-Code reflector. Your job is to analyze a session event log and extract generalized, reusable heuristics into the project's knowledge base.

## Input

You will receive a path to a session event log (`.sage/events/session-<id>.jsonl`) and the project's `.sage/knowledge/` directory.

## Process

### Step 1: PARSE
Read the session event log. Identify:
- **Corrections** (`type: "correction"`, `signal: "negative"`) — things the user told Claude to do differently
- **Failures** (`type: "tool_outcome"`, `success: false`) — tools that errored
- **Successes** (`type: "positive_signal"`) — things the user praised
- **Patterns** — repeated tool usage, file paths touched, commands run

If the session has fewer than 5 tool_outcome events, or has zero corrections/failures/positive_signals, output "No actionable learnings from this session." and stop.

### Step 2: EVALUATE
For each correction/failure:
- What went wrong? Extract the specific mistake.
- Is this project-specific (references project files/patterns) or general?
- Would this be useful to remember for future sessions?

For each positive signal:
- What approach was used just before the praise?
- Is this a codifiable strategy or just acknowledgment?

### Step 3: ABSTRACT
Generalize specific instances into reusable heuristics. Transform:
- "user said 'no, use async/await instead of .then()'" → "ALWAYS use async/await over .then() chains"
- "npm test failed with 'Cannot find module @/utils'" → "NEVER use @/ aliases without verifying tsconfig paths are configured"

Each heuristic MUST have:
- **Heading:** Start with ALWAYS or NEVER when possible, otherwise a clear imperative
- **Category:** One of: pitfall, strategy, preference, architecture, convention
- **Confidence:** low (this is first observation)
- **Scope:** project (if references project specifics) or language/universal
- **Evidence:** The session ID being analyzed

### Step 4: MERGE
Read existing knowledge files in `.sage/knowledge/`.

For each new heuristic:
1. Search ALL knowledge files for an existing entry that covers the same concept (fuzzy match on meaning, not exact text)
2. If **duplicate found**: Edit the existing entry to increment its confidence (low→medium if 2-3 observations, medium→high if 4+), add this session ID to Evidence, update "Last seen" date
3. If **contradictory rule found**: If the existing rule has higher confidence, keep it and add a note. If equal or lower confidence, demote the existing rule and add the new one.
4. If **novel**: Append to the appropriate knowledge file

### Step 5: WRITE
Write/edit the knowledge files. Use this exact format for each entry:

```markdown
### HEADING_TEXT
- **Confidence:** low (1 observation)
- **Scope:** project
- **Rule:** Detailed explanation of what to do or avoid and why.
- **Evidence:** sessions SESSION_ID
- **Added:** YYYY-MM-DD
- **Last seen:** YYYY-MM-DD
```

## Rules
- NEVER invent heuristics that aren't directly supported by the event log
- NEVER create entries for trivial observations ("user ran git status")
- Prefer fewer, higher-quality heuristics over many weak ones
- One heuristic per distinct concept — don't bundle unrelated learnings
- Keep Rule text concise (1-3 sentences max)
```

Write to `sage-code/agents/reflector.md`.

- [ ] **Step 2: Commit**

```bash
git add sage-code/agents/reflector.md
git commit -m "feat: add reflector subagent definition for session analysis"
```

---

## Task 9: Knowledge Curator Subagent

**Files:**
- Create: `sage-code/agents/knowledge-curator.md`

- [ ] **Step 1: Write the knowledge curator agent definition**

```markdown
---
description: Organizes, deduplicates, and maintains the SAGE-Code knowledge base. Enforces size limits, merges redundant entries, and updates the project README and CLAUDE.md.
model: sonnet
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Knowledge Curator Agent

You maintain the SAGE-Code knowledge base quality. You are dispatched after meta-evaluation to clean up and organize knowledge files.

## Tasks

### 1. Deduplicate
Read all files in `.sage/knowledge/`. Find entries that express the same concept (even with different wording). Merge them:
- Keep the higher-confidence version's heading
- Combine evidence lists
- Use the highest confidence level
- Keep the earliest "Added" date and latest "Last seen" date

### 2. Consolidate
Look for entries that are closely related and could be combined into a broader rule. For example:
- "NEVER use var" + "ALWAYS use const over let when possible" → "ALWAYS use const by default, let when reassignment needed, never var"

Only consolidate when the combined rule is clearer than the separate ones.

### 3. Enforce Size Limits
Read `.sage/meta/config.json` for `max_knowledge_entries_per_file` (default: 100).

If any knowledge file exceeds this limit:
1. Sort entries by confidence (high first) then by last_seen (recent first)
2. Archive entries beyond the limit to `.sage/meta/archive.md`
3. Archived entries keep their full format with an added `- **Archived:** YYYY-MM-DD (reason: size limit)` field

### 4. Prune Stale Entries
Read `.sage/meta/config.json` for `stale_days` (default: 30).
Remove entries where "Last seen" is older than stale_days ago.
Archive them with reason "stale".

Respect `new_rule_grace_days` — never prune entries added within the grace period.

### 5. Update CLAUDE.md
Read the project's `CLAUDE.md` (if it exists).

Find the managed section between:
```
## Sage Learnings
<!-- Auto-managed by sage-code plugin. Do not edit below this line. -->
...
<!-- End sage-code managed section -->
```

Replace its contents with all heuristics that have `confidence: high`. Format as a simple bullet list:
```
- ALWAYS use async/await over .then() chains
- NEVER commit .env files — use .env.example
```

If the managed section doesn't exist, append it to the end of CLAUDE.md.
If CLAUDE.md doesn't exist, create it with just the managed section.

### 6. Update .sage/README.md
Count total heuristics across all knowledge files. Count by confidence level.
Update the stats in `.sage/README.md`:
```
**Sessions analyzed:** <count from events directory>
**Heuristics learned:** <total> (<high> high, <medium> medium, <low> low)
```
```

Write to `sage-code/agents/knowledge-curator.md`.

- [ ] **Step 2: Commit**

```bash
git add sage-code/agents/knowledge-curator.md
git commit -m "feat: add knowledge-curator subagent for dedup, pruning, and CLAUDE.md sync"
```

---

## Task 10: Meta-Evaluator Subagent

**Files:**
- Create: `sage-code/agents/meta-evaluator.md`

- [ ] **Step 1: Write the meta-evaluator agent definition**

```markdown
---
description: Evaluates the effectiveness of SAGE-Code heuristics by correlating them with session outcomes. Promotes, demotes, or prunes rules based on evidence.
model: sonnet
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Meta-Evaluator Agent

You evaluate whether SAGE-Code's learned heuristics are actually helping. You analyze the correlation between replayed heuristics and session outcomes.

## Input

You have access to:
- `.sage/knowledge/*.md` — Current heuristic inventory
- `.sage/events/*.jsonl` — Recent session event logs
- `.sage/meta/scores.json` — Previous score history
- `.sage/meta/config.json` — Scoring thresholds

## Process

### Step 1: Inventory
Read all knowledge files. Build a list of all heuristics with their IDs (generated as `{category}-{slugified-heading}`), categories, confidence levels, and evidence.

### Step 2: Outcome Correlation
For each heuristic, examine the session event logs listed in its Evidence field:
- Count total sessions where this heuristic's domain was relevant
- Count corrections/failures in those sessions that relate to this heuristic's topic
- A heuristic is "effective" if sessions with more evidence show FEWER related corrections over time

Scoring rubric:
- **1.0** — No related corrections in any session after the rule was created
- **0.8** — Corrections decreased over time
- **0.6** — No clear trend (neutral)
- **0.4** — Corrections continued at similar rate
- **0.2** — Corrections increased or rule was contradicted
- **0.0** — Rule was actively harmful (caused errors)

### Step 3: Update Scores
Read `.sage/meta/scores.json`. For each heuristic:

If it already has a score entry:
- Update `score` as weighted average: `new_score = 0.7 * old_score + 0.3 * current_eval`
- Increment `observations`
- Set `trend` based on last 3 evaluations: "rising" if improving, "declining" if worsening, "stable" otherwise
- Update `last_eval` to today

If it's new (no score entry):
- Create entry with current evaluation as initial score, observations=1, trend="stable"

Write the updated scores back to `.sage/meta/scores.json`.

### Step 4: Take Action
Read thresholds from `.sage/meta/config.json`:
- `promote_score_threshold` (default: 0.7)
- `prune_score_threshold` (default: 0.2)
- `prune_min_observations` (default: 10)
- `new_rule_grace_days` (default: 7)

For each heuristic:

**PROMOTE** (score > promote_threshold AND confidence is high):
- No direct action needed — knowledge-curator handles CLAUDE.md sync
- Log promotion in `.sage/meta/history.json`

**DEMOTE** (score < 0.4 AND trend is "declining" AND observations >= 5):
- Edit the knowledge file to drop confidence by one level (high→medium, medium→low)
- Log demotion in history

**PRUNE** (score < prune_threshold AND observations >= prune_min):
- Check `new_rule_grace_days` — skip if rule was added within grace period
- Remove the entry from the knowledge file
- Append it to `.sage/meta/archive.md` with `- **Archived:** YYYY-MM-DD (reason: score {score} after {observations} observations)`
- Log pruning in history

### Step 5: Record History
Append an evaluation record to `.sage/meta/history.json`:
```json
{
  "date": "YYYY-MM-DD",
  "heuristics_evaluated": 47,
  "promoted": 2,
  "demoted": 1,
  "pruned": 0,
  "avg_score": 0.65
}
```

Reset `sessions_since_eval` to 0 and update `last_meta_eval` in config.json.

## Rules
- NEVER prune rules within the grace period
- NEVER change scores by more than 0.3 in a single evaluation (smoothing)
- ALWAYS log actions in history.json for audit trail
- Be conservative — when uncertain about a rule's effectiveness, RETAIN rather than prune
```

Write to `sage-code/agents/meta-evaluator.md`.

- [ ] **Step 2: Commit**

```bash
git add sage-code/agents/meta-evaluator.md
git commit -m "feat: add meta-evaluator subagent for heuristic effectiveness scoring"
```

---

## Task 11: sage-replay Skill (Main Orchestrator)

**Files:**
- Create: `sage-code/skills/sage-replay/SKILL.md`

- [ ] **Step 1: Write the sage-replay skill**

```markdown
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

Check for unprocessed session logs:

1. Use Glob to find files matching `.sage/events/*.unprocessed`
2. For each `.unprocessed` marker file found:
   a. Determine the corresponding event log (replace `.unprocessed` with `.jsonl`)
   b. Read the event log to check if it has enough signal (≥5 tool_outcome events AND at least 1 correction/failure/positive_signal)
   c. If sufficient signal: dispatch the `reflector` subagent with this prompt:
      ```
      Analyze the session event log at [PATH] and update the knowledge files in .sage/knowledge/.
      Read existing knowledge files first to check for duplicates before adding new entries.
      ```
   d. After the reflector completes, delete the `.unprocessed` marker file
   e. If insufficient signal: delete the `.unprocessed` marker file without reflection

Process at most 3 unprocessed sessions to avoid long startup times. Leave older ones for the next session.

## Phase 2: Knowledge Replay

Load relevant knowledge for the current session:

1. Read `.sage/meta/config.json` to get `replay_max_heuristics` (default: 15)
2. Read the session event log (the most recent one in `.sage/events/`) to get the `session_start` event with git context (`branch`, `diff_files`, `recent_commits`)
3. Read ALL knowledge files in `.sage/knowledge/`
4. Score each heuristic for relevance to the current context:

   **Scoring rules:**
   - +3 if the heuristic's Rule text mentions any file path that appears in `diff_files`
   - +2 if the heuristic's category is "pitfall" (pitfalls always rank higher)
   - +1 if the heuristic's "Last seen" date is within the last 7 days
   - +1 if the heuristic's confidence is "high"
   - +1 if the heuristic's Rule text mentions keywords from the branch name

5. Sort heuristics by score (descending), take the top N (from config)
6. Output a concise context block:

```
## Sage Context for This Session
Based on your current work (branch: {branch}, files: {top 3 diff files}):
- {heuristic 1 heading} ({confidence})
- {heuristic 2 heading} ({confidence})
- ...
```

If no knowledge files exist or all are empty, output:
```
Sage: No prior learnings for this project. I'll begin learning from this session.
```

## Phase 3: Meta-Evaluation Check

1. Read `.sage/meta/config.json`
2. Check if `sessions_since_eval` >= `meta_eval_interval_sessions` OR if `last_meta_eval` is more than `meta_eval_interval_days` days ago
3. If meta-evaluation is due: dispatch the `sage-meta` skill by outputting:
   ```
   [sage] Meta-evaluation due. Run /sage-meta to evaluate heuristic effectiveness.
   ```

## Rules
- NEVER take more than 30 seconds for replay — this runs at session start
- NEVER process more than 3 unprocessed sessions at once
- ALWAYS output the Sage Context block, even if empty
- Keep the context block under 500 tokens
```

Write to `sage-code/skills/sage-replay/SKILL.md`.

- [ ] **Step 2: Commit**

```bash
git add sage-code/skills/sage-replay/SKILL.md
git commit -m "feat: add sage-replay skill for reflection processing and knowledge replay"
```

---

## Task 12: sage-reflect Skill (Manual Trigger)

**Files:**
- Create: `sage-code/skills/sage-reflect/SKILL.md`

- [ ] **Step 1: Write the sage-reflect skill**

```markdown
---
name: sage-reflect
description: Manually trigger SAGE-Code reflection on the current session's events. Use when you want to process learnings without waiting for the next session.
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
---

# Manual Reflection Trigger

Force reflection on the current session's events immediately.

## Process

1. Use Glob to find the most recent event log in `.sage/events/` (by modification time)
2. Read it to verify it has content
3. Dispatch the `reflector` subagent:
   ```
   Analyze the session event log at [PATH] and update the knowledge files in .sage/knowledge/.
   Read existing knowledge files first to check for duplicates before adding new entries.
   ```
4. After reflection completes, report what was learned:
   - Read the git diff on `.sage/knowledge/` to see what changed
   - Summarize the new/updated heuristics for the user
5. Remove the `.unprocessed` marker if one exists for this session

Output a summary like:
```
## Sage Reflection Complete

**New heuristics:**
- [low] ALWAYS validate input before database queries (pitfall)

**Updated heuristics:**
- [medium → high] NEVER use synchronous file operations in API routes (pitfall)

**No changes:** Session had no actionable learnings
```
```

Write to `sage-code/skills/sage-reflect/SKILL.md`.

- [ ] **Step 2: Commit**

```bash
git add sage-code/skills/sage-reflect/SKILL.md
git commit -m "feat: add sage-reflect skill for manual reflection trigger"
```

---

## Task 13: sage-meta Skill

**Files:**
- Create: `sage-code/skills/sage-meta/SKILL.md`

- [ ] **Step 1: Write the sage-meta skill**

```markdown
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

Evaluate whether SAGE-Code's learned heuristics are actually improving outcomes.

## Process

1. Dispatch the `meta-evaluator` subagent:
   ```
   Evaluate all heuristics in .sage/knowledge/ against session outcomes in .sage/events/.
   Update scores in .sage/meta/scores.json.
   Promote, demote, or prune heuristics based on thresholds in .sage/meta/config.json.
   Log all actions in .sage/meta/history.json.
   Reset sessions_since_eval to 0 and update last_meta_eval in config.json.
   ```

2. After evaluation completes, dispatch the `knowledge-curator` subagent:
   ```
   Clean up the knowledge base in .sage/knowledge/:
   - Deduplicate entries that express the same concept
   - Consolidate closely related entries
   - Enforce size limits from .sage/meta/config.json
   - Prune entries stale beyond stale_days
   - Update the ## Sage Learnings section in CLAUDE.md with high-confidence rules
   - Update stats in .sage/README.md
   ```

3. Report results:
   ```
   ## Sage Meta-Evaluation Complete

   **Evaluated:** N heuristics
   **Promoted:** N (moved to CLAUDE.md)
   **Demoted:** N (confidence lowered)
   **Pruned:** N (removed, archived)
   **Average score:** 0.XX
   ```
```

Write to `sage-code/skills/sage-meta/SKILL.md`.

- [ ] **Step 2: Commit**

```bash
git add sage-code/skills/sage-meta/SKILL.md
git commit -m "feat: add sage-meta skill for periodic heuristic evaluation"
```

---

## Task 14: sage-status Skill

**Files:**
- Create: `sage-code/skills/sage-status/SKILL.md`

- [ ] **Step 1: Write the sage-status skill**

```markdown
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

1. Read `.sage/meta/config.json` for configuration
2. Count session event logs in `.sage/events/` (count `.jsonl` files)
3. Read all knowledge files in `.sage/knowledge/`
4. For each entry, extract confidence level and category
5. Read `.sage/meta/scores.json` for score data
6. Read `.sage/meta/history.json` for last meta-evaluation date
7. Check how many entries are in the `## Sage Learnings` section of `CLAUDE.md`

## Output Format

```
## Sage Status for {project directory}

Sessions analyzed: {count of .jsonl files}
Heuristics learned: {total} ({high} high, {medium} medium, {low} low)
Promoted to CLAUDE.md: {count in managed section}
Pruned (ineffective): {count in archive.md}
Last meta-evaluation: {date from history.json or "never"}

### Top Learnings (by confidence)
1. [high] {heading from knowledge file}
2. [high] {heading}
3. [medium] {heading}
...

### Recently Learned (last 7 days)
1. [low] {heading} ({category})
2. [low] {heading} ({category})

### Category Breakdown
- Pitfalls: {count}
- Strategies: {count}
- Preferences: {count}
- Architecture: {count}
- Conventions: {count}
```

If `.sage/` directory doesn't exist, output:
```
Sage has not been initialized in this project yet.
It will start learning automatically on your next session.
```
```

Write to `sage-code/skills/sage-status/SKILL.md`.

- [ ] **Step 2: Commit**

```bash
git add sage-code/skills/sage-status/SKILL.md
git commit -m "feat: add sage-status skill for viewing learned heuristics"
```

---

## Task 15: Test Fixtures

**Files:**
- Create: `sage-code/tests/fixtures/sample-events.jsonl`
- Create: `sage-code/tests/run-all.sh`

- [ ] **Step 1: Create sample event log fixture**

```jsonl
{"ts":"2026-04-15T22:30:00Z","type":"session_start","session_id":"fixture-001","branch":"feature/auth","cwd":"/project","recent_commits":["add login endpoint","fix cors"],"diff_files":["src/auth/login.ts","src/auth/middleware.ts"]}
{"ts":"2026-04-15T22:31:00Z","type":"tool_outcome","tool":"Read","file":"src/auth/login.ts","success":true}
{"ts":"2026-04-15T22:32:00Z","type":"tool_outcome","tool":"Edit","file":"src/auth/login.ts","success":true}
{"ts":"2026-04-15T22:33:00Z","type":"correction","signal":"negative","raw":"no, use bcrypt instead of md5 for password hashing"}
{"ts":"2026-04-15T22:34:00Z","type":"tool_outcome","tool":"Edit","file":"src/auth/login.ts","success":true}
{"ts":"2026-04-15T22:35:00Z","type":"tool_outcome","tool":"Bash","cmd":"npm test","success":true}
{"ts":"2026-04-15T22:36:00Z","type":"positive_signal","raw":"perfect, that's exactly right"}
{"ts":"2026-04-15T22:37:00Z","type":"tool_outcome","tool":"Write","file":"src/auth/middleware.ts","success":true}
{"ts":"2026-04-15T22:38:00Z","type":"tool_outcome","tool":"Bash","cmd":"npm test","success":false,"error":"Error: JWT_SECRET not defined in env"}
{"ts":"2026-04-15T22:39:00Z","type":"tool_outcome","tool":"Edit","file":".env.example","success":true}
{"ts":"2026-04-15T22:40:00Z","type":"tool_outcome","tool":"Bash","cmd":"npm test","success":true}
{"ts":"2026-04-15T22:45:00Z","type":"session_end","tools_used":8,"errors":1,"corrections":1,"positive_signals":1,"files_modified":3,"duration_s":900}
```

Write to `sage-code/tests/fixtures/sample-events.jsonl`.

- [ ] **Step 2: Create test runner**

```bash
#!/usr/bin/env bash
# sage-code/tests/run-all.sh
# Run all SAGE-Code tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  test_name=$(basename "$test_file")
  echo ""
  echo "━━━ Running $test_name ━━━"
  if bash "$test_file"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$FAIL" -eq 0 ] || exit 1
```

Write to `sage-code/tests/run-all.sh` and `chmod +x`.

- [ ] **Step 3: Run all tests**

```bash
bash sage-code/tests/run-all.sh
```

Expected: All 4 tests pass (sage-init, on-session-start, on-tool-use, on-correction, on-session-end).

- [ ] **Step 4: Commit**

```bash
git add sage-code/tests/
git commit -m "feat: add test fixtures and test runner"
```

---

## Task 16: Integration Test

**Files:**
- Create: `sage-code/tests/test-full-flow.sh`

- [ ] **Step 1: Write integration test**

```bash
#!/usr/bin/env bash
# sage-code/tests/test-full-flow.sh
# Integration test: simulate a complete session lifecycle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

export SAGE_PROJECT_DIR="$TEST_DIR"
export CLAUDE_SESSION_ID="integration-test-001"

echo "=== Integration Test: Full Session Lifecycle ==="

# Step 1: Initialize (simulates first SessionStart)
echo "--- Step 1: SessionStart ---"
RESPONSE=$(bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" 2>/dev/null)

# Verify .sage/ was bootstrapped
if [ ! -d "$TEST_DIR/.sage" ]; then
  echo "FAIL: .sage/ not bootstrapped on first session"
  exit 1
fi

# Verify systemMessage returned
if ! echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'systemMessage' in d" 2>/dev/null; then
  echo "FAIL: No systemMessage in SessionStart response"
  exit 1
fi
echo "OK: Session started, .sage/ bootstrapped"

# Step 2: Simulate tool usage
echo "--- Step 2: Tool usage ---"
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"},"tool_result":"File edited"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null
echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_result":"Error: test failed"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null
echo '{"tool_name":"Read","tool_input":{"file_path":"src/app.ts"},"tool_result":"contents"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

EVENT_LOG="$TEST_DIR/.sage/events/session-integration-test-001.jsonl"
# Should have: 1 session_start + 2 tool_outcomes (Read skipped) = 3
LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 3 ]; then
  echo "FAIL: Expected 3 events, got $LINES"
  exit 1
fi
echo "OK: 2 tool outcomes captured (Read skipped)"

# Step 3: Simulate corrections
echo "--- Step 3: Corrections ---"
echo '{"user_input":"no, use const instead of let"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null
echo '{"user_input":"perfect, exactly what I wanted"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null
echo '{"user_input":"can you add a logger?"}' | \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
# 3 + 2 (correction + positive, normal skipped) = 5
if [ "$LINES" -ne 5 ]; then
  echo "FAIL: Expected 5 events after corrections, got $LINES"
  exit 1
fi
echo "OK: 1 correction + 1 positive captured (normal skipped)"

# Step 4: End session
echo "--- Step 4: SessionEnd ---"
bash "$SCRIPT_DIR/hooks/scripts/on-session-end.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 6 ]; then
  echo "FAIL: Expected 6 events after session end, got $LINES"
  exit 1
fi

# Verify .unprocessed marker exists
if [ ! -f "$TEST_DIR/.sage/events/session-integration-test-001.unprocessed" ]; then
  echo "FAIL: .unprocessed marker not created"
  exit 1
fi

# Verify session_end summary
SUMMARY=$(tail -1 "$EVENT_LOG")
if ! echo "$SUMMARY" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['type']=='session_end'
assert d['tools_used']==2
assert d['errors']==1
assert d['corrections']==1
assert d['positive_signals']==1
" 2>/dev/null; then
  echo "FAIL: Session summary incorrect: $SUMMARY"
  exit 1
fi
echo "OK: Session ended with correct summary"

# Step 5: Verify config was updated
SESSIONS_COUNT=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.sage/meta/config.json'))['sessions_since_eval'])" 2>/dev/null)
if [ "$SESSIONS_COUNT" -ne 1 ]; then
  echo "FAIL: sessions_since_eval should be 1, got $SESSIONS_COUNT"
  exit 1
fi
echo "OK: sessions_since_eval incremented"

echo ""
echo "PASS: Full session lifecycle integration test passed"
```

Write to `sage-code/tests/test-full-flow.sh` and `chmod +x`.

- [ ] **Step 2: Run integration test**

```bash
bash sage-code/tests/test-full-flow.sh
```

Expected: PASS.

- [ ] **Step 3: Run all tests**

```bash
bash sage-code/tests/run-all.sh
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add sage-code/tests/test-full-flow.sh
git commit -m "feat: add full lifecycle integration test"
```

---

## Task 17: Final Verification

- [ ] **Step 1: Verify complete plugin structure**

```bash
find sage-code -type f | sort
```

Expected output should match the plugin structure from the spec.

- [ ] **Step 2: Run all tests one final time**

```bash
bash sage-code/tests/run-all.sh
```

Expected: All tests pass.

- [ ] **Step 3: Verify all files are committed**

```bash
git status
git log --oneline
```

Expected: Clean working tree, commits for each task.
