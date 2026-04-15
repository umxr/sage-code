#!/usr/bin/env bats

load test_helper

HOOK=""
SESSION_ID="tool-test-session"
EVENT_LOG=""

setup() {
  setup_sage_env
  HOOK="$SCRIPT_DIR/hooks/scripts/on-tool-use.sh"
  export CLAUDE_SESSION_ID="$SESSION_ID"
  init_sage
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  touch "$EVENT_LOG"
}

teardown() {
  teardown_sage_env
}

@test "Write tool is captured as tool_outcome" {
  WRITE_INPUT='{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.py","content":"hello"},"tool_result":"File written successfully"}'
  echo "$WRITE_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"

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
  READ_INPUT='{"tool_name":"Read","tool_input":{"file_path":"/tmp/foo.py"},"tool_result":"hello"}'
  echo "$READ_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "Bash failure is detected correctly" {
  BASH_FAIL_INPUT='{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_result":"Error: 2 tests failed\nexit code 1"}'
  echo "$BASH_FAIL_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
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
  BASH_OK_INPUT='{"tool_name":"Bash","tool_input":{"command":"echo hello"},"tool_result":"hello"}'
  echo "$BASH_OK_INPUT" | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  run python3 -c "
import json
last = open('$EVENT_LOG').readlines()[-1]
d = json.loads(last)
print(str(d.get('success','')).lower())
"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "Glob tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  echo '{"tool_name":"Glob","tool_input":{},"tool_result":"result"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "Grep tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  echo '{"tool_name":"Grep","tool_input":{},"tool_result":"result"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "WebSearch tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  echo '{"tool_name":"WebSearch","tool_input":{},"tool_result":"result"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "WebFetch tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  echo '{"tool_name":"WebFetch","tool_input":{},"tool_result":"result"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "TodoWrite tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  echo '{"tool_name":"TodoWrite","tool_input":{},"tool_result":"result"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "AskUserQuestion tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  echo '{"tool_name":"AskUserQuestion","tool_input":{},"tool_result":"result"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "ListMcpResourcesTool tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  echo '{"tool_name":"ListMcpResourcesTool","tool_input":{},"tool_result":"result"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "ReadMcpResourceTool tool is skipped" {
  BEFORE_COUNT=$(wc -l < "$EVENT_LOG")
  echo '{"tool_name":"ReadMcpResourceTool","tool_input":{},"tool_result":"result"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER_COUNT=$(wc -l < "$EVENT_LOG")
  [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ]
}

@test "hook exits silently when event log is missing" {
  MISSING_DIR=$(mktemp -d)
  SAGE_PROJECT_DIR="$MISSING_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
  # Intentionally do NOT create the event log
  WRITE_INPUT='{"tool_name":"Write","tool_input":{"file_path":"/tmp/bar.py"},"tool_result":"ok"}'
  run bash -c "echo '$WRITE_INPUT' | SAGE_PROJECT_DIR='$MISSING_DIR' CLAUDE_SESSION_ID='no-log-session' bash '$HOOK' 2>/dev/null"
  rm -rf "$MISSING_DIR"
  [ "$status" -eq 0 ]
}
