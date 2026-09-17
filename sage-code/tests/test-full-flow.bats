#!/usr/bin/env bats

load test_helper

SESSION_ID="integration-test-001"
EVENT_LOG=""

setup() {
  setup_sage_env
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
}

teardown() {
  teardown_sage_env
}

@test "full flow: session start bootstraps .sage/ directory" {
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1
  [ -d "$TEST_DIR/.sage" ]
}

@test "full flow: session start creates event log" {
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1
  [ -f "$EVENT_LOG" ]
}

@test "full flow: Edit and Bash tool events are captured, Read is skipped (3 total events)" {
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  tool_payload Edit '{"file_path":"src/app.ts"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  tool_failure_payload Bash '{"command":"npm test"}' $'Exit code 1\nError: test failed' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  tool_payload Read '{"file_path":"src/app.ts"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
  [ "$LINES" -eq 3 ]
}

@test "full flow: corrections and positive signals are captured, neutral is skipped (5 total events)" {
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  tool_payload Edit '{"file_path":"src/app.ts"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  tool_failure_payload Bash '{"command":"npm test"}' $'Exit code 1\nError: test failed' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  tool_payload Read '{"file_path":"src/app.ts"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  prompt_payload "no, use const instead of let" | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  prompt_payload "perfect, exactly what I wanted" | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  prompt_payload "can you add a logger?" | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
  [ "$LINES" -eq 5 ]
}

@test "full flow: session end appends session_end event (6 total events)" {
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  tool_payload Edit '{"file_path":"src/app.ts"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  tool_failure_payload Bash '{"command":"npm test"}' $'Exit code 1\nError: test failed' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  tool_payload Read '{"file_path":"src/app.ts"}' | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-tool-use.sh" 2>/dev/null

  prompt_payload "no, use const instead of let" | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  prompt_payload "perfect, exactly what I wanted" | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  prompt_payload "can you add a logger?" | \
    SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-correction.sh" 2>/dev/null

  session_end_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-end.sh" 2>/dev/null

  LINES=$(wc -l < "$EVENT_LOG" | tr -d ' ')
  [ "$LINES" -eq 6 ]
}

@test "full flow: session end creates .unprocessed marker" {
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  session_end_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-end.sh" 2>/dev/null

  [ -f "$TEST_DIR/.sage/events/session-${SESSION_ID}.unprocessed" ]
}

@test "full flow: last event is session_end type" {
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  session_end_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
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
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" \
    bash "$SCRIPT_DIR/hooks/scripts/on-session-start.sh" > /dev/null 2>&1

  SESSIONS_COUNT=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.sage/meta/config.json'))['sessions_since_eval'])")
  [ "$SESSIONS_COUNT" -ge 1 ]
}
