#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

HOOK="$SCRIPT_DIR/hooks/scripts/on-tool-use.sh"
INIT="$SCRIPT_DIR/bin/sage-init.sh"

echo "=== Test: on-tool-use.sh ==="

PASS=true

# ── Setup: bootstrap .sage/ and create an event log ───────────────────────
SESSION_ID="tool-test-session"
SAGE_PROJECT_DIR="$TEST_DIR" bash "$INIT"
EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
touch "$EVENT_LOG"

# ── Test 1: Write tool is captured ────────────────────────────────────────
echo "--- Test 1: Write tool captured as tool_outcome ---"
WRITE_INPUT='{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.py","content":"hello"},"tool_result":"File written successfully"}'
echo "$WRITE_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"

LINE_COUNT=$(wc -l < "$EVENT_LOG")
if [ "$LINE_COUNT" -lt 1 ]; then
  echo "FAIL: No event appended to log for Write tool"
  PASS=false
else
  LAST_EVENT=$(tail -n1 "$EVENT_LOG")
  EVENT_TYPE=$(echo "$LAST_EVENT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('type',''))")
  if [ "$EVENT_TYPE" != "tool_outcome" ]; then
    echo "FAIL: expected type=tool_outcome, got '$EVENT_TYPE'"
    PASS=false
  else
    echo "PASS: Write tool captured as tool_outcome"
  fi
fi

# ── Test 2: Read tool is skipped ──────────────────────────────────────────
echo "--- Test 2: Read tool skipped ---"
BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
READ_INPUT='{"tool_name":"Read","tool_input":{"file_path":"/tmp/foo.py"},"tool_result":"hello"}'
echo "$READ_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
AFTER_COUNT=$(wc -l < "$EVENT_LOG")
if [ "$AFTER_COUNT" -ne "$BEFORE_COUNT" ]; then
  echo "FAIL: Read tool was captured (should be skipped). Before=$BEFORE_COUNT After=$AFTER_COUNT"
  PASS=false
else
  echo "PASS: Read tool skipped"
fi

# ── Test 3: Bash failure is detected ─────────────────────────────────────
echo "--- Test 3: Bash failure detected correctly ---"
BASH_FAIL_INPUT='{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_result":"Error: 2 tests failed\nexit code 1"}'
echo "$BASH_FAIL_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
LAST_EVENT=$(tail -n1 "$EVENT_LOG")
SUCCESS=$(echo "$LAST_EVENT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',''))")
if [ "$SUCCESS" != "False" ] && [ "$SUCCESS" != "false" ]; then
  echo "FAIL: Bash failure not detected. success='$SUCCESS', event: $LAST_EVENT"
  PASS=false
else
  echo "PASS: Bash failure detected correctly"
fi

# ── Test 4: Bash success is detected ─────────────────────────────────────
echo "--- Test 4: Bash success detected correctly ---"
BASH_OK_INPUT='{"tool_name":"Bash","tool_input":{"command":"echo hello"},"tool_result":"hello"}'
echo "$BASH_OK_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
LAST_EVENT=$(tail -n1 "$EVENT_LOG")
SUCCESS=$(echo "$LAST_EVENT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',''))")
if [ "$SUCCESS" != "True" ] && [ "$SUCCESS" != "true" ]; then
  echo "FAIL: Bash success not detected. success='$SUCCESS'"
  PASS=false
else
  echo "PASS: Bash success detected correctly"
fi

# ── Test 5: Skip all read-only tools ─────────────────────────────────────
echo "--- Test 5: All read-only tools skipped ---"
BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
for tool in Glob Grep WebSearch WebFetch TodoWrite AskUserQuestion ListMcpResourcesTool ReadMcpResourceTool; do
  SKIP_INPUT="{\"tool_name\":\"$tool\",\"tool_input\":{},\"tool_result\":\"result\"}"
  echo "$SKIP_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
done
AFTER_COUNT=$(wc -l < "$EVENT_LOG")
if [ "$AFTER_COUNT" -ne "$BEFORE_COUNT" ]; then
  echo "FAIL: Some read-only tools were captured. Before=$BEFORE_COUNT After=$AFTER_COUNT"
  PASS=false
else
  echo "PASS: All read-only tools skipped"
fi

# ── Test 6: Hook exits silently if no event log ───────────────────────────
echo "--- Test 6: Hook exits silently if event log missing ---"
MISSING_DIR=$(mktemp -d)
trap 'rm -rf "$MISSING_DIR"' EXIT
SAGE_PROJECT_DIR="$MISSING_DIR" bash "$INIT"
# Intentionally do NOT create the event log
WRITE_INPUT2='{"tool_name":"Write","tool_input":{"file_path":"/tmp/bar.py"},"tool_result":"ok"}'
if echo "$WRITE_INPUT2" | SAGE_PROJECT_DIR="$MISSING_DIR" CLAUDE_SESSION_ID="no-log-session" bash "$HOOK" 2>/dev/null; then
  echo "PASS: Hook exited silently when event log missing"
else
  echo "FAIL: Hook did not exit cleanly when event log missing"
  PASS=false
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
if $PASS; then
  echo "PASS: All on-tool-use.sh tests passed"
else
  echo "FAIL: Some tests failed"
  exit 1
fi
