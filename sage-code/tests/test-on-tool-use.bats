#!/usr/bin/env bats

load test_helper

HOOK=""
SESSION_ID="tool-test-session"
EVENT_LOG=""

setup() {
  setup_sage_env
  HOOK="$SCRIPT_DIR/hooks/scripts/on-tool-use.sh"
  init_sage
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  touch "$EVENT_LOG"
}

teardown() {
  teardown_sage_env
}

@test "Write tool is captured as tool_outcome" {
  WRITE_INPUT=$(tool_payload Write '{"file_path":"/tmp/foo.py","content":"hello"}')
  echo "$WRITE_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"

  LINE_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$LINE_COUNT" -ge 1 ]

  run python3 -c "
import json
last = open('$EVENT_LOG').readlines()[-1]
d = json.loads(last)
print(d.get('type',''))
"
  [ "$status" -eq 0 ]
  [ "$output" = "tool_outcome" ]
}

@test "Read tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  READ_INPUT=$(tool_payload Read '{"file_path":"/tmp/foo.py"}')
  echo "$READ_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "Bash failure is detected correctly" {
  BASH_FAIL_INPUT=$(tool_failure_payload Bash '{"command":"npm test"}' $'Exit code 1\nError: 2 tests failed')
  echo "$BASH_FAIL_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  run python3 -c "
import json
last = open('$EVENT_LOG').readlines()[-1]
d = json.loads(last)
print(str(d.get('success','')).lower())
"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "Bash success is detected correctly" {
  BASH_OK_INPUT=$(tool_payload Bash '{"command":"echo hello"}')
  echo "$BASH_OK_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  run python3 -c "
import json
last = open('$EVENT_LOG').readlines()[-1]
d = json.loads(last)
print(str(d.get('success','')).lower())
"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "failure event records the start of the error text" {
  tool_failure_payload Bash '{"command":"npm test"}' $'Exit code 1\nError: Cannot find module' | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  run python3 -c "
import json
d = json.loads(open('$EVENT_LOG').readlines()[-1])
assert d['success'] is False
assert d['error'].startswith('Exit code 1')
assert d['command'] == 'npm test'
"
  [ "$status" -eq 0 ]
}

@test "a successful tool call is not marked as a failure because its text says error" {
  tool_payload Write '{"file_path":"/tmp/error-handler.py","content":"raise Exception(\"failed\")"}' | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  run python3 -c "
import json
d = json.loads(open('$EVENT_LOG').readlines()[-1])
assert d['success'] is True
assert 'error' not in d
"
  [ "$status" -eq 0 ]
}

@test "session ID is read from the hook input, not from the environment" {
  OTHER_LOG="$TEST_DIR/.sage/events/session-other-session.jsonl"
  touch "$OTHER_LOG"
  SESSION_ID="other-session" tool_payload Bash '{"command":"ls"}' | CLAUDE_SESSION_ID="$SESSION_ID" SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ "$(wc -l < "$OTHER_LOG" | tr -d ' ')" -eq 1 ]
  [ "$(wc -l < "$EVENT_LOG" | tr -d ' ')" -eq 0 ]
}

@test "Glob tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  tool_payload Glob | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "Grep tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  tool_payload Grep | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "WebSearch tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  tool_payload WebSearch | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "WebFetch tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  tool_payload WebFetch | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "TodoWrite tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  tool_payload TodoWrite | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "AskUserQuestion tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  tool_payload AskUserQuestion | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "ListMcpResourcesTool tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  tool_payload ListMcpResourcesTool | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "ReadMcpResourceTool tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  tool_payload ReadMcpResourceTool | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "hook exits silently when event log is missing" {
  MISSING_DIR=$(mktemp -d)
  SAGE_PROJECT_DIR="$MISSING_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
  # Intentionally do NOT create the event log
  WRITE_INPUT=$(SESSION_ID="no-log-session" tool_payload Write '{"file_path":"/tmp/bar.py"}')
  run bash -c "echo '$WRITE_INPUT' | SAGE_PROJECT_DIR='$MISSING_DIR' bash '$HOOK' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ ! -f "$MISSING_DIR/.sage/events/session-no-log-session.jsonl" ]
  rm -rf "$MISSING_DIR"
}
