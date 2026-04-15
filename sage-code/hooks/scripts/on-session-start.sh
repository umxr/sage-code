#!/usr/bin/env bash
set -euo pipefail

# ── Environment ────────────────────────────────────────────────────────────
SAGE_PROJECT_DIR="${SAGE_PROJECT_DIR:-$(pwd)}"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
SAGE_DIR="$SAGE_PROJECT_DIR/.sage"
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# ── Bootstrap .sage/ if needed ─────────────────────────────────────────────
if [ ! -d "$SAGE_DIR" ]; then
  SAGE_PROJECT_DIR="$SAGE_PROJECT_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
fi

# ── Prepare event log ──────────────────────────────────────────────────────
EVENT_LOG="$SAGE_DIR/events/session-${SESSION_ID}.jsonl"
mkdir -p "$SAGE_DIR/events"

# ── Gather git context (gracefully) ───────────────────────────────────────
BRANCH=""
RECENT_COMMITS="[]"
DIFF_FILES="[]"

if git -C "$SAGE_PROJECT_DIR" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  BRANCH=$(git -C "$SAGE_PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  RECENT_COMMITS=$(git -C "$SAGE_PROJECT_DIR" log --oneline -5 --no-decorate 2>/dev/null \
    | python3 -c "import sys,json; lines=[l.strip() for l in sys.stdin if l.strip()]; print(json.dumps(lines))" \
    || echo "[]")
  DIFF_FILES=$(git -C "$SAGE_PROJECT_DIR" diff --name-only HEAD 2>/dev/null \
    | python3 -c "import sys,json; lines=[l.strip() for l in sys.stdin if l.strip()]; print(json.dumps(lines))" \
    || echo "[]")
fi

# ── Write session_start event ──────────────────────────────────────────────
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

python3 - <<PYEOF >> "$EVENT_LOG"
import json, sys
event = {
    "ts": "$TS",
    "type": "session_start",
    "session_id": "$SESSION_ID",
    "branch": "$BRANCH",
    "cwd": "$SAGE_PROJECT_DIR",
    "recent_commits": $RECENT_COMMITS,
    "diff_files": $DIFF_FILES,
}
print(json.dumps(event))
PYEOF

# ── Increment sessions_since_eval in config.json ──────────────────────────
CONFIG="$SAGE_DIR/meta/config.json"
python3 - <<PYEOF
import json
with open("$CONFIG") as f:
    cfg = json.load(f)
cfg["sessions_since_eval"] = cfg.get("sessions_since_eval", 0) + 1
with open("$CONFIG", "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF

# ── Output system message ─────────────────────────────────────────────────
python3 -c "import json; print(json.dumps({'systemMessage': '[sage-code] Session initialized. Run /sage-replay to load project knowledge and process any pending reflections.'}))"
