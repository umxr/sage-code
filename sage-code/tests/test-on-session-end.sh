#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

HOOK="$SCRIPT_DIR/hooks/scripts/on-session-end.sh"
INIT="$SCRIPT_DIR/bin/sage-init.sh"

echo "=== Test: on-session-end.sh ==="

PASS=true

# ── Setup: bootstrap .sage/ and seed a known event log ────────────────────
SESSION_ID="end-test-session"
SAGE_PROJECT_DIR="$TEST_DIR" bash "$INIT"
EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"

# Seed the log with known events:
# - 1 session_start
# - 3 tool_outcome (2 success, 1 failure)
# - 1 correction (negative)
# - 1 positive_signal
# - 2 files modified (Write tools with file_path)
python3 << PYEOF
import json
from datetime import datetime, timezone

def ts(offset=0):
    # Use a fixed base time for deterministic duration test
    return "2026-04-15T10:00:{:02d}Z".format(offset)

events = [
    {"ts": ts(0),  "type": "session_start",  "session_id": "$SESSION_ID", "branch": "main", "cwd": "/proj", "recent_commits": [], "diff_files": []},
    {"ts": ts(5),  "type": "tool_outcome",   "tool": "Write",  "file_path": "/proj/foo.py", "command": "", "success": True},
    {"ts": ts(10), "type": "tool_outcome",   "tool": "Write",  "file_path": "/proj/bar.py", "command": "", "success": True},
    {"ts": ts(15), "type": "tool_outcome",   "tool": "Bash",   "file_path": "",             "command": "npm test", "success": False},
    {"ts": ts(20), "type": "correction",     "signal": "negative", "excerpt": "no, wrong"},
    {"ts": ts(25), "type": "positive_signal","signal": "positive", "excerpt": "perfect!"},
]
with open("$EVENT_LOG", "w") as f:
    for e in events:
        f.write(json.dumps(e) + "\n")
PYEOF

# ── Run the hook ───────────────────────────────────────────────────────────
SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"

# ── Test 1: session_end event appended ────────────────────────────────────
echo "--- Test 1: session_end event appended ---"
LAST_EVENT=$(tail -n1 "$EVENT_LOG")
EVENT_TYPE=$(echo "$LAST_EVENT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('type',''))")
if [ "$EVENT_TYPE" != "session_end" ]; then
  echo "FAIL: last event type is '$EVENT_TYPE', expected 'session_end'"
  PASS=false
else
  echo "PASS: session_end event appended"
fi

# ── Test 2: summary counts are correct ────────────────────────────────────
echo "--- Test 2: summary counts correct ---"
export _TEST_EVENT_LOG="$EVENT_LOG"
if python3 << 'PYEOF'
import json, sys, os

event_log = os.environ.get("_TEST_EVENT_LOG", "")
with open(event_log) as f:
    lines = [json.loads(l) for l in f if l.strip()]

end = lines[-1]
summary = end.get("summary", {})

checks = {
    "tools_used":       (summary.get("tools_used"), 3),           # Write x2 + Bash x1
    "errors":           (summary.get("errors"), 1),               # 1 failure
    "corrections":      (summary.get("corrections"), 1),          # 1 negative
    "positive_signals": (summary.get("positive_signals"), 1),     # 1 positive
    "files_modified":   (summary.get("files_modified"), 2),       # 2 unique file_paths
}

fail = False
for field, (got, want) in checks.items():
    if got != want:
        print(f"FAIL: {field} = {got!r}, expected {want!r}")
        fail = True

if fail:
    sys.exit(1)
else:
    print("PASS: all summary counts correct")
PYEOF
then
  : # already printed PASS
else
  PASS=false
fi

# ── Test 3: .unprocessed marker file exists ───────────────────────────────
echo "--- Test 3: .unprocessed marker file created ---"
MARKER="$TEST_DIR/.sage/events/session-${SESSION_ID}.unprocessed"
if [ ! -f "$MARKER" ]; then
  echo "FAIL: .unprocessed marker not created at $MARKER"
  PASS=false
else
  echo "PASS: .unprocessed marker created"
fi

# ── Test 4: duration_s field present and non-negative ────────────────────
echo "--- Test 4: duration_s present and >= 0 ---"
DURATION=$(tail -n1 "$EVENT_LOG" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('summary',{}).get('duration_s','MISSING'))")
if [ "$DURATION" = "MISSING" ]; then
  echo "FAIL: duration_s missing from session_end summary"
  PASS=false
elif python3 -c "import sys; sys.exit(0 if float('$DURATION') >= 0 else 1)"; then
  echo "PASS: duration_s = $DURATION (>= 0)"
else
  echo "FAIL: duration_s = $DURATION (negative)"
  PASS=false
fi

# ── Test 5: Hook exits silently if .sage/ missing ─────────────────────────
echo "--- Test 5: Hook exits silently if .sage/ missing ---"
EMPTY_DIR=$(mktemp -d)
trap 'rm -rf "$EMPTY_DIR"' EXIT
if SAGE_PROJECT_DIR="$EMPTY_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK" 2>/dev/null; then
  echo "PASS: hook exits silently when .sage/ missing"
else
  echo "FAIL: hook errored when .sage/ missing"
  PASS=false
fi

# ── Test 6: Hook exits silently if event log missing ─────────────────────
echo "--- Test 6: Hook exits silently if event log missing ---"
NO_LOG_DIR=$(mktemp -d)
trap 'rm -rf "$NO_LOG_DIR"' EXIT
SAGE_PROJECT_DIR="$NO_LOG_DIR" bash "$INIT"
if SAGE_PROJECT_DIR="$NO_LOG_DIR" CLAUDE_SESSION_ID="no-log-session" bash "$HOOK" 2>/dev/null; then
  echo "PASS: hook exits silently when event log missing"
else
  echo "FAIL: hook errored when event log missing"
  PASS=false
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
if $PASS; then
  echo "PASS: All on-session-end.sh tests passed"
else
  echo "FAIL: Some tests failed"
  exit 1
fi
