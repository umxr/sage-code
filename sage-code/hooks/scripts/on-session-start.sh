#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook.
# Claude Code sends the event as JSON on stdin, with `session_id` and `source`
# (startup, resume, clear, compact, or fork). This hook runs synchronously so
# that its additionalContext reaches Claude before the first prompt.

# ── Environment ────────────────────────────────────────────────────────────
SAGE_PROJECT_DIR="${SAGE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
SAGE_DIR="$SAGE_PROJECT_DIR/.sage"
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# ── Read stdin ─────────────────────────────────────────────────────────────
export _HOOK_INPUT
_HOOK_INPUT=$(cat)

# Session ID comes from the hook input; keep it safe for use in a file name
SESSION_ID=$(python3 -c '
import json, os, re
try:
    data = json.loads(os.environ.get("_HOOK_INPUT", ""))
except json.JSONDecodeError:
    data = {}
print(re.sub(r"[^A-Za-z0-9._-]", "_", str(data.get("session_id") or "unknown")))
')

# ── Bootstrap .sage/ if needed ─────────────────────────────────────────────
if [ ! -d "$SAGE_DIR" ]; then
  SAGE_PROJECT_DIR="$SAGE_PROJECT_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
fi

# ── Prepare event log ──────────────────────────────────────────────────────
EVENT_LOG="$SAGE_DIR/events/session-${SESSION_ID}.jsonl"
mkdir -p "$SAGE_DIR/events"

# ── Gather git context (gracefully) ───────────────────────────────────────
BRANCH=""
RECENT_COMMITS=""
DIFF_FILES=""

if git -C "$SAGE_PROJECT_DIR" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  BRANCH=$(git -C "$SAGE_PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  RECENT_COMMITS=$(git -C "$SAGE_PROJECT_DIR" log --oneline -5 --no-decorate 2>/dev/null || echo "")
  DIFF_FILES=$(git -C "$SAGE_PROJECT_DIR" diff --name-only HEAD 2>/dev/null || echo "")
fi

export _HOOK_SESSION_ID="$SESSION_ID"
export _HOOK_PROJECT_DIR="$SAGE_PROJECT_DIR"
export _HOOK_SAGE_DIR="$SAGE_DIR"
export _HOOK_EVENT_LOG="$EVENT_LOG"
export _HOOK_BRANCH="$BRANCH"
export _HOOK_RECENT_COMMITS="$RECENT_COMMITS"
export _HOOK_DIFF_FILES="$DIFF_FILES"

python3 << 'PYEOF'
import glob, json, os
from datetime import datetime, timezone

env        = os.environ
session_id = env.get("_HOOK_SESSION_ID", "unknown")
sage_dir   = env.get("_HOOK_SAGE_DIR", "")
event_log  = env.get("_HOOK_EVENT_LOG", "")

try:
    data = json.loads(env.get("_HOOK_INPUT", ""))
except json.JSONDecodeError:
    data = {}

def lines(value):
    return [l.strip() for l in value.splitlines() if l.strip()]

def has_session_start(path):
    try:
        with open(path) as f:
            for line in f:
                try:
                    if json.loads(line).get("type") == "session_start":
                        return True
                except json.JSONDecodeError:
                    pass
    except OSError:
        pass
    return False

# SessionStart also fires on resume and compaction with the same session ID.
# Only the first firing for a session writes session_start and counts it.
# The log can exist before this hook runs: the InstructionsLoaded hook creates
# it when a rule loads at the start of the session.
is_new_session = not has_session_start(event_log)

config = os.path.join(sage_dir, "meta", "config.json")
with open(config) as f:
    cfg = json.load(f)

if is_new_session:
    event = {
        "ts":             datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "type":           "session_start",
        "session_id":     session_id,
        "source":         data.get("source", "startup"),
        "branch":         env.get("_HOOK_BRANCH", ""),
        "cwd":            env.get("_HOOK_PROJECT_DIR", ""),
        "recent_commits": lines(env.get("_HOOK_RECENT_COMMITS", "")),
        "diff_files":     lines(env.get("_HOOK_DIFF_FILES", "")),
    }
    with open(event_log, "a") as f:
        f.write(json.dumps(event) + "\n")

    # ── Increment sessions_since_eval in config.json ──────────────────────
    cfg["sessions_since_eval"] = cfg.get("sessions_since_eval", 0) + 1
    with open(config, "w") as f:
        json.dump(cfg, f, indent=2)

# ── Tell Claude when there is a task for it ───────────────────────────────
# Published rules need no notice: Claude Code loads .claude/rules/sage/ itself.
own_marker = f"session-{session_id}.unprocessed"
pending = sum(
    1
    for path in glob.glob(os.path.join(sage_dir, "events", "*.unprocessed"))
    if os.path.basename(path) != own_marker
)

since_eval = cfg.get("sessions_since_eval", 0)
interval   = cfg.get("meta_eval_interval_sessions", 10)
meta_due   = since_eval >= interval

if pending == 0 and not meta_due:
    raise SystemExit(0)

# additionalContext is written as statements of fact, not as commands
facts = ["[sage-code] This project has a SAGE-Code knowledge base in .sage/."]
if pending:
    facts.append(
        f"{pending} earlier session log(s) in .sage/events/ are not reflected on yet. "
        "The sage-code:sage-replay skill processes the pending reflections."
    )
if meta_due:
    facts.append(
        f"Meta-evaluation is due: {since_eval} sessions since the last one "
        f"(the interval is {interval}). The sage-code:sage-meta skill runs it."
    )
context = " ".join(facts)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName":     "SessionStart",
        "additionalContext": context,
    }
}))
PYEOF
