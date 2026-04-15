#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

export SAGE_PROJECT_DIR="$TEST_DIR"
export CLAUDE_SESSION_ID="integration-test-001"

echo "=== Integration Test: Full Session Lifecycle ==="

# Step 1: SessionStart (should bootstrap .sage/)
echo "--- Step 1: SessionStart ---"
RESPONSE=$(bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" 2>/dev/null)

if [ ! -d "$TEST_DIR/.sage" ]; then
  echo "FAIL: .sage/ not bootstrapped on first session"
  exit 1
fi

if ! echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'systemMessage' in d" 2>/dev/null; then
  echo "FAIL: No systemMessage in SessionStart response"
  exit 1
fi
echo "OK: Session started, .sage/ bootstrapped"

# Step 2: Tool usage
echo "--- Step 2: Tool usage ---"
EVENT_LOG="$TEST_DIR/.sage/events/session-integration-test-001.jsonl"

echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"},"tool_result":"File edited"}' | \
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="integration-test-001" \
  bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_result":"Error: test failed"}' | \
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="integration-test-001" \
  bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

echo '{"tool_name":"Read","tool_input":{"file_path":"src/app.ts"},"tool_result":"contents"}' | \
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="integration-test-001" \
  bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
if [ "$LINES" -ne 3 ]; then
  echo "FAIL: Expected 3 events (1 start + 2 tools, Read skipped), got $LINES"
  exit 1
fi
echo "OK: 2 tool outcomes captured (Read skipped)"

# Step 3: Corrections
echo "--- Step 3: Corrections ---"
echo '{"user_input":"no, use const instead of let"}' | \
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="integration-test-001" \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

echo '{"user_input":"perfect, exactly what I wanted"}' | \
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="integration-test-001" \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

echo '{"user_input":"can you add a logger?"}' | \
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="integration-test-001" \
  bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
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
" 2>/dev/null; then
  echo "FAIL: Last event is not session_end"
  exit 1
fi
echo "OK: Session ended with summary"

# Step 5: Config updated
SESSIONS_COUNT=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.sage/meta/config.json'))['sessions_since_eval'])" 2>/dev/null)
if [ "$SESSIONS_COUNT" -lt 1 ]; then
  echo "FAIL: sessions_since_eval should be >= 1, got $SESSIONS_COUNT"
  exit 1
fi
echo "OK: sessions_since_eval incremented"

echo ""
echo "PASS: Full session lifecycle integration test passed"
