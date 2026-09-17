#!/usr/bin/env bats

load test_helper

HOOK=""
SESSION_ID="rules-test-session"
EVENT_LOG=""
RULE_FILE=""

setup() {
  setup_sage_env
  HOOK="$SCRIPT_DIR/hooks/scripts/on-instructions-loaded.sh"
  init_sage
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  mkdir -p "$TEST_DIR/.claude/rules/sage/nested" "$TEST_DIR/src/auth"
  RULE_FILE="$TEST_DIR/.claude/rules/sage/pitfall-never-use-md5.md"
  echo "# NEVER use md5" > "$RULE_FILE"
  touch "$TEST_DIR/src/auth/login.ts"
}

teardown() {
  teardown_sage_env
}

# Helper: get a field of the last event in the log
_last_event_field() {
  python3 -c "import json; d=json.loads(open('$EVENT_LOG').readlines()[-1]); print(d.get('$1',''))"
}

@test "sage rule load is recorded as rule_loaded with the rule ID" {
  instructions_loaded_payload "$RULE_FILE" session_start | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ "$(_last_event_field type)" = "rule_loaded" ]
  [ "$(_last_event_field rule_id)" = "pitfall-never-use-md5" ]
  [ "$(_last_event_field load_reason)" = "session_start" ]
  [ "$(_last_event_field trigger_file)" = "" ]
}

@test "path match load records the trigger file relative to the project" {
  instructions_loaded_payload "$RULE_FILE" path_glob_match "$TEST_DIR/src/auth/login.ts" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ "$(_last_event_field load_reason)" = "path_glob_match" ]
  [ "$(_last_event_field trigger_file)" = "src/auth/login.ts" ]
}

@test "event log is created when it does not exist" {
  [ ! -f "$EVENT_LOG" ]
  instructions_loaded_payload "$RULE_FILE" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ -f "$EVENT_LOG" ]
  [ "$(wc -l < "$EVENT_LOG" | tr -d ' ')" -eq 1 ]
}

@test "CLAUDE.md load is ignored" {
  echo "# Project" > "$TEST_DIR/CLAUDE.md"
  instructions_loaded_payload "$TEST_DIR/CLAUDE.md" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ ! -f "$EVENT_LOG" ]
}

@test "rule file outside sage/ is ignored" {
  echo "# team" > "$TEST_DIR/.claude/rules/team.md"
  instructions_loaded_payload "$TEST_DIR/.claude/rules/team.md" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ ! -f "$EVENT_LOG" ]
}

@test "file in a subdirectory of sage/ is ignored" {
  echo "# nested" > "$TEST_DIR/.claude/rules/sage/nested/x.md"
  instructions_loaded_payload "$TEST_DIR/.claude/rules/sage/nested/x.md" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ ! -f "$EVENT_LOG" ]
}

@test "load after compaction is ignored" {
  instructions_loaded_payload "$RULE_FILE" compact | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ ! -f "$EVENT_LOG" ]
}

@test "hook exits silently when .sage/ directory is missing" {
  EMPTY_DIR=$(mktemp -d)
  PAYLOAD=$(instructions_loaded_payload "$EMPTY_DIR/.claude/rules/sage/a.md")
  run bash -c "echo '$PAYLOAD' | SAGE_PROJECT_DIR='$EMPTY_DIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -d "$EMPTY_DIR/.sage" ]
  rm -rf "$EMPTY_DIR"
}

@test "hooks.json registers the InstructionsLoaded hook without the compact reason" {
  run python3 -c "
import json
entry = json.load(open('$SCRIPT_DIR/hooks/hooks.json'))['hooks']['InstructionsLoaded'][0]
assert 'compact' not in entry['matcher'].split('|')
assert 'path_glob_match' in entry['matcher'].split('|')
assert entry['hooks'][0]['args'][0].endswith('/hooks/scripts/on-instructions-loaded.sh')
"
  [ "$status" -eq 0 ]
}
