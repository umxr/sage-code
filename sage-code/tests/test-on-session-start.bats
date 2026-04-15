#!/usr/bin/env bats

load test_helper

HOOK=""

setup() {
  setup_sage_env
  HOOK="$SCRIPT_DIR/hooks/scripts/on-session-start.sh"
}

teardown() {
  teardown_sage_env
}

@test "on-session-start creates event log for session ID" {
  SESSION_ID="test-session-001"
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK" > /dev/null
  [ -f "$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl" ]
}

@test "on-session-start first event has type session_start" {
  SESSION_ID="test-session-001"
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK" > /dev/null
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  run python3 -c "import sys,json; d=json.loads(open('$EVENT_LOG').readline()); print(d.get('type',''))"
  [ "$status" -eq 0 ]
  [ "$output" = "session_start" ]
}

@test "on-session-start event contains all required fields" {
  SESSION_ID="test-session-001"
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK" > /dev/null
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  run python3 -c "
import sys, json
d = json.loads(open('$EVENT_LOG').readline())
required = ['ts', 'type', 'session_id', 'branch', 'cwd', 'recent_commits', 'diff_files']
missing = [k for k in required if k not in d]
if missing:
    print(f'missing fields: {missing}')
    sys.exit(1)
"
  [ "$status" -eq 0 ]
}

@test "on-session-start stdout contains systemMessage" {
  SESSION_ID="test-session-002"
  run bash -c "SAGE_PROJECT_DIR='$TEST_DIR' CLAUDE_SESSION_ID='$SESSION_ID' bash '$HOOK'"
  [ "$status" -eq 0 ]
  run python3 -c "import sys,json; d=json.loads('$output'); print('yes' if 'systemMessage' in d else 'no')" <<< "$output"
  # Use a subshell to capture and test the output directly
  HAS_SYS_MSG=$(SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'systemMessage' in d else 'no')")
  [ "$HAS_SYS_MSG" = "yes" ]
}

@test "on-session-start increments sessions_since_eval" {
  SESSION_ID_A="test-session-001"
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID_A" bash "$HOOK" > /dev/null
  BEFORE=$(python3 -c "import json; d=json.load(open('$TEST_DIR/.sage/meta/config.json')); print(d['sessions_since_eval'])")

  SESSION_ID_B="test-session-002"
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID_B" bash "$HOOK" > /dev/null
  AFTER=$(python3 -c "import json; d=json.load(open('$TEST_DIR/.sage/meta/config.json')); print(d['sessions_since_eval'])")

  [ "$AFTER" -gt "$BEFORE" ]
}

@test "on-session-start handles non-git directory gracefully" {
  NON_GIT_DIR=$(mktemp -d)
  SESSION_ID="test-session-004"
  run bash -c "SAGE_PROJECT_DIR='$NON_GIT_DIR' CLAUDE_SESSION_ID='$SESSION_ID' bash '$HOOK' 2>/dev/null | python3 -c 'import sys,json; json.load(sys.stdin)' > /dev/null 2>&1"
  rm -rf "$NON_GIT_DIR"
  [ "$status" -eq 0 ]
}
