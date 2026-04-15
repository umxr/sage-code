#!/usr/bin/env bats

load test_helper

SESSION_ID="integration-test-001"
EVENT_LOG=""

setup() {
  setup_sage_env
  export CLAUDE_SESSION_ID="$SESSION_ID"
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
}

teardown() {
  teardown_sage_env
}

@test "full flow: session start bootstraps .sage/ directory" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1
  [ -d "$TEST_DIR/.sage" ]
}

@test "full flow: session start returns systemMessage" {
  RESPONSE=$(SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" 2>/dev/null)
  run python3 -c "import json,sys; d=json.loads('$RESPONSE'.replace(\"'\", \"'\")); assert 'systemMessage' in d" <<< "$RESPONSE"
  # Use python3 via pipe
  run bash -c "SAGE_PROJECT_DIR='$TEST_DIR' CLAUDE_SESSION_ID='$SESSION_ID' bash '$SCRIPT_DIR/hooks/scripts/on-session-start.sh' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"systemMessage\" in d'"
  [ "$status" -eq 0 ]
}

@test "full flow: session start creates event log" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1
  [ -f "$EVENT_LOG" ]
}

@test "full flow: Edit and Bash tool events are captured, Read is skipped (3 total events)" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"},"tool_result":"File edited"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_result":"Error: test failed"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  echo '{"tool_name":"Read","tool_input":{"file_path":"src/app.ts"},"tool_result":"contents"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
  [ "$LINES" -eq 3 ]
}

@test "full flow: corrections and positive signals are captured, neutral is skipped (5 total events)" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"},"tool_result":"File edited"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_result":"Error: test failed"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  echo '{"tool_name":"Read","tool_input":{"file_path":"src/app.ts"},"tool_result":"contents"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  echo '{"user_input":"no, use const instead of let"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  echo '{"user_input":"perfect, exactly what I wanted"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  echo '{"user_input":"can you add a logger?"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
  [ "$LINES" -eq 5 ]
}

@test "full flow: session end appends session_end event (6 total events)" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"},"tool_result":"File edited"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_result":"Error: test failed"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  echo '{"tool_name":"Read","tool_input":{"file_path":"src/app.ts"},"tool_result":"contents"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  echo '{"user_input":"no, use const instead of let"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  echo '{"user_input":"perfect, exactly what I wanted"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  echo '{"user_input":"can you add a logger?"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-end.sh" 2>/dev/null

  LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
  [ "$LINES" -eq 6 ]
}

@test "full flow: session end creates .unprocessed marker" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-end.sh" 2>/dev/null

  [ -f "$TEST_DIR/.sage/events/session-${SESSION_ID}.unprocessed" ]
}

@test "full flow: last event is session_end type" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-end.sh" 2>/dev/null

  run python3 -c "
import json
last = open('$EVENT_LOG').readlines()[-1]
d = json.loads(last)
assert d['type'] == 'session_end'
"
  [ "$status" -eq 0 ]
}

@test "full flow: sessions_since_eval is incremented in config" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  SESSIONS_COUNT=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.sage/meta/config.json'))['sessions_since_eval'])")
  [ "$SESSIONS_COUNT" -ge 1 ]
}
