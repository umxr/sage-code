#!/usr/bin/env bats

load test_helper

HOOK=""
SESSION_ID="correction-test-session"
EVENT_LOG=""

setup() {
  setup_sage_env
  HOOK="$SCRIPT_DIR/hooks/scripts/on-correction.sh"
  export CLAUDE_SESSION_ID="$SESSION_ID"
  init_sage
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  touch "$EVENT_LOG"
}

teardown() {
  teardown_sage_env
}

# Helper: get last event field value from the log
_last_event_field() {
  local field="$1"
  python3 -c "import json; d=json.loads(open('$EVENT_LOG').readlines()[-1]); print(d.get('$field',''))"
}

@test "'no, use async/await' is captured as correction/negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"no, use async/await instead"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
  [ "$(_last_event_field type)" = "correction" ]
  [ "$(_last_event_field signal)" = "negative" ]
}

@test "'perfect, exactly what I needed' is captured as positive_signal/positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"perfect, exactly what I needed"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
  [ "$(_last_event_field type)" = "positive_signal" ]
  [ "$(_last_event_field signal)" = "positive" ]
}

@test "'can you add a function' is NOT captured" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"can you add a function to parse JSON"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -eq "$BEFORE" ]
}

@test "short message under 5 chars is skipped" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"no"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -eq "$BEFORE" ]
}

@test "'don't do it that way' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"don'\''t do it that way"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'stop using var' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"stop using var"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'wrong, use const' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"wrong, use const"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'actually, you should use map' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"actually, you should use map"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'instead, try a loop' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"instead, try a loop"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'not that one' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"not that one"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's wrong' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"that'\''s wrong"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'never use eval' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"never use eval"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'always use strict mode' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"always use strict mode"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'remember: avoid globals' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"remember: avoid globals"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'exactly right!' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"exactly right!"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'great, that works' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"great, that works"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'awesome solution' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"awesome solution"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'nice implementation' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"nice implementation"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'yes, that's right' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"yes, that'\''s right"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'yes that's correct' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"yes that'\''s correct"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's perfect' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"that'\''s perfect"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's exactly it' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"that'\''s exactly it"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's correct' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"that'\''s correct"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's right' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"that'\''s right"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'good job on that' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"good job on that"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'good work here' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"good work here"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'good call' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  echo '{"user_input":"good call"}' | SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "hook exits silently when event log is missing" {
  MISSING_DIR=$(mktemp -d)
  SAGE_PROJECT_DIR="$MISSING_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
  run bash -c "echo '{\"user_input\":\"no, wrong approach\"}' | SAGE_PROJECT_DIR='$MISSING_DIR' CLAUDE_SESSION_ID='no-log' bash '$HOOK' 2>/dev/null"
  rm -rf "$MISSING_DIR"
  [ "$status" -eq 0 ]
}
