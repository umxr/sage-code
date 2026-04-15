#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

HOOK="$SCRIPT_DIR/hooks/scripts/on-session-start.sh"

echo "=== Test: on-session-start.sh ==="

PASS=true

# ── Test 1: event log is created ───────────────────────────────────────────
echo "--- Test 1: event log created for session ID ---"
SESSION_ID="test-session-001"
SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK" > /dev/null

EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
if [ ! -f "$EVENT_LOG" ]; then
  echo "FAIL: event log not created at $EVENT_LOG"
  PASS=false
else
  echo "PASS: event log created"
fi

# ── Test 2: first line is a session_start event ────────────────────────────
echo "--- Test 2: first line is session_start type ---"
EVENT_TYPE=$(head -n1 "$EVENT_LOG" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('type',''))")
if [ "$EVENT_TYPE" != "session_start" ]; then
  echo "FAIL: expected type=session_start, got '$EVENT_TYPE'"
  PASS=false
else
  echo "PASS: first event type is session_start"
fi

# ── Test 3: event contains required fields ─────────────────────────────────
echo "--- Test 3: event contains required fields ---"
if head -n1 "$EVENT_LOG" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
required = ['ts', 'type', 'session_id', 'branch', 'cwd', 'recent_commits', 'diff_files']
missing = [k for k in required if k not in d]
if missing:
    print(f'FAIL: missing fields: {missing}')
    sys.exit(1)
else:
    print('PASS: all required fields present')
"; then
  : # already printed PASS
else
  PASS=false
fi

# ── Test 4: stdout contains systemMessage ─────────────────────────────────
echo "--- Test 4: stdout contains systemMessage ---"
SESSION_ID2="test-session-002"
OUTPUT2=$(SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID2" bash "$HOOK")
HAS_SYS_MSG=$(echo "$OUTPUT2" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'systemMessage' in d else 'no')")
if [ "$HAS_SYS_MSG" != "yes" ]; then
  echo "FAIL: stdout does not contain systemMessage. Got: $OUTPUT2"
  PASS=false
else
  echo "PASS: systemMessage present in stdout"
fi

# ── Test 5: sessions_since_eval incremented ────────────────────────────────
echo "--- Test 5: sessions_since_eval incremented ---"
BEFORE=$(python3 -c "import json; d=json.load(open('$TEST_DIR/.sage/meta/config.json')); print(d['sessions_since_eval'])")
SESSION_ID3="test-session-003"
SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID3" bash "$HOOK" > /dev/null
AFTER=$(python3 -c "import json; d=json.load(open('$TEST_DIR/.sage/meta/config.json')); print(d['sessions_since_eval'])")
if [ "$AFTER" -le "$BEFORE" ]; then
  echo "FAIL: sessions_since_eval not incremented (before=$BEFORE, after=$AFTER)"
  PASS=false
else
  echo "PASS: sessions_since_eval incremented ($BEFORE -> $AFTER)"
fi

# ── Test 6: graceful in non-git directory ─────────────────────────────────
echo "--- Test 6: works in non-git directory ---"
NON_GIT_DIR=$(mktemp -d)
trap 'rm -rf "$NON_GIT_DIR"' EXIT
SESSION_ID4="test-session-004"
if SAGE_PROJECT_DIR="$NON_GIT_DIR" CLAUDE_SESSION_ID="$SESSION_ID4" bash "$HOOK" 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin)" > /dev/null 2>&1; then
  echo "PASS: non-git dir handled gracefully"
else
  echo "FAIL: non-git dir caused error"
  PASS=false
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
if $PASS; then
  echo "PASS: All on-session-start.sh tests passed"
else
  echo "FAIL: Some tests failed"
  exit 1
fi
