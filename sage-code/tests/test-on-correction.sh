#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

HOOK="$SCRIPT_DIR/hooks/scripts/on-correction.sh"
INIT="$SCRIPT_DIR/bin/sage-init.sh"

echo "=== Test: on-correction.sh ==="

PASS=true

# ── Setup: bootstrap .sage/ and create a session event log ────────────────
SESSION_ID="correction-test-session"
SAGE_PROJECT_DIR="$TEST_DIR" bash "$INIT"
EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
touch "$EVENT_LOG"

# Helper: get the last event type from the log
last_event_type() {
  tail -n1 "$EVENT_LOG" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('type',''))"
}
last_event_signal() {
  tail -n1 "$EVENT_LOG" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('signal',''))"
}

# ── Test 1: "no, use async/await" → negative correction ──────────────────
echo "--- Test 1: 'no, use async/await' captured as negative ---"
BEFORE=$(wc -l < "$EVENT_LOG")
echo '{"user_input":"no, use async/await instead"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
AFTER=$(wc -l < "$EVENT_LOG")
if [ "$AFTER" -le "$BEFORE" ]; then
  echo "FAIL: No event appended"
  PASS=false
else
  ETYPE=$(last_event_type)
  ESIG=$(last_event_signal)
  if [ "$ETYPE" = "correction" ] && [ "$ESIG" = "negative" ]; then
    echo "PASS: captured as correction/negative"
  else
    echo "FAIL: expected correction/negative, got type=$ETYPE signal=$ESIG"
    PASS=false
  fi
fi

# ── Test 2: "perfect, exactly what I needed" → positive signal ───────────
echo "--- Test 2: 'perfect, exactly what I needed' captured as positive ---"
BEFORE=$(wc -l < "$EVENT_LOG")
echo '{"user_input":"perfect, exactly what I needed"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
AFTER=$(wc -l < "$EVENT_LOG")
if [ "$AFTER" -le "$BEFORE" ]; then
  echo "FAIL: No event appended"
  PASS=false
else
  ETYPE=$(last_event_type)
  ESIG=$(last_event_signal)
  if [ "$ETYPE" = "positive_signal" ] && [ "$ESIG" = "positive" ]; then
    echo "PASS: captured as positive_signal/positive"
  else
    echo "FAIL: expected positive_signal/positive, got type=$ETYPE signal=$ESIG"
    PASS=false
  fi
fi

# ── Test 3: "can you add a function" → NOT captured ──────────────────────
echo "--- Test 3: 'can you add a function' NOT captured ---"
BEFORE=$(wc -l < "$EVENT_LOG")
echo '{"user_input":"can you add a function to parse JSON"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
AFTER=$(wc -l < "$EVENT_LOG")
if [ "$AFTER" -ne "$BEFORE" ]; then
  echo "FAIL: Neutral prompt was captured (Before=$BEFORE After=$AFTER)"
  PASS=false
else
  echo "PASS: neutral prompt not captured"
fi

# ── Test 4: short message (< 5 chars) skipped ─────────────────────────────
echo "--- Test 4: Short message skipped ---"
BEFORE=$(wc -l < "$EVENT_LOG")
echo '{"user_input":"no"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
AFTER=$(wc -l < "$EVENT_LOG")
if [ "$AFTER" -ne "$BEFORE" ]; then
  echo "FAIL: Short message was captured"
  PASS=false
else
  echo "PASS: short message skipped"
fi

# ── Test 5: additional negative patterns ─────────────────────────────────
echo "--- Test 5: Additional negative patterns captured ---"
for msg in "don't do it that way" "stop using var" "wrong, use const" "actually, you should use map" "instead, try a loop" "not that one" "that's wrong" "never use eval" "always use strict mode" "remember: avoid globals"; do
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo "{\"user_input\":\"$msg\"}" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  if [ "$AFTER" -le "$BEFORE" ]; then
    echo "FAIL: '$msg' not captured"
    PASS=false
  fi
done
echo "PASS: additional negative patterns captured"

# ── Test 6: additional positive patterns ─────────────────────────────────
echo "--- Test 6: Additional positive patterns captured ---"
for msg in "exactly right!" "great, that works" "awesome solution" "nice implementation" "yes, that's right" "yes that's correct" "that's perfect" "that's exactly it" "that's correct" "that's right" "good job on that" "good work here" "good call"; do
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo "{\"user_input\":\"$msg\"}" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  if [ "$AFTER" -le "$BEFORE" ]; then
    echo "FAIL: '$msg' not captured as positive"
    PASS=false
  fi
done
echo "PASS: additional positive patterns captured"

# ── Test 7: Hook exits silently if event log missing ─────────────────────
echo "--- Test 7: Hook exits silently if event log missing ---"
MISSING_DIR=$(mktemp -d)
trap 'rm -rf "$MISSING_DIR"' EXIT
SAGE_PROJECT_DIR="$MISSING_DIR" bash "$INIT"
if echo '{"user_input":"no, wrong approach"}' | SAGE_PROJECT_DIR="$MISSING_DIR" CLAUDE_SESSION_ID="no-log" bash "$HOOK" 2>/dev/null; then
  echo "PASS: hook exits silently when log missing"
else
  echo "FAIL: hook errored when log missing"
  PASS=false
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
if $PASS; then
  echo "PASS: All on-correction.sh tests passed"
else
  echo "FAIL: Some tests failed"
  exit 1
fi
