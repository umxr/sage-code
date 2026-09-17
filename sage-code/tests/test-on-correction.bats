#!/usr/bin/env bats

load test_helper

HOOK=""
SESSION_ID="correction-test-session"
EVENT_LOG=""

setup() {
  setup_sage_env
  HOOK="$SCRIPT_DIR/hooks/scripts/on-correction.sh"
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
  prompt_payload "no, use async/await instead" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
  [ "$(_last_event_field type)" = "correction" ]
  [ "$(_last_event_field signal)" = "negative" ]
}

@test "'perfect, exactly what I needed' is captured as positive_signal/positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "perfect, exactly what I needed" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
  [ "$(_last_event_field type)" = "positive_signal" ]
  [ "$(_last_event_field signal)" = "positive" ]
}

@test "'can you add a function' is NOT captured" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "can you add a function to parse JSON" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -eq "$BEFORE" ]
}

@test "short message under 5 chars is skipped" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "no" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -eq "$BEFORE" ]
}

@test "'don't do it that way' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "don't do it that way" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'stop using var' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "stop using var" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'wrong, use const' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "wrong, use const" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'actually, you should use map' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "actually, you should use map" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'instead, try a loop' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "instead, try a loop" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'not that one' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "not that one" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's wrong' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "that's wrong" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'never use eval' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "never use eval" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'always use strict mode' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "always use strict mode" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'remember: avoid globals' is captured as negative" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "remember: avoid globals" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'exactly right!' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "exactly right!" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'great, that works' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "great, that works" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'awesome solution' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "awesome solution" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'nice implementation' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "nice implementation" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'yes, that's right' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "yes, that's right" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'yes that's correct' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "yes that's correct" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's perfect' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "that's perfect" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's exactly it' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "that's exactly it" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's correct' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "that's correct" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'that's right' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "that's right" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'good job on that' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "good job on that" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'good work here' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "good work here" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "'good call' is captured as positive" {
  BEFORE=$(wc -l < "$EVENT_LOG")
  prompt_payload "good call" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  AFTER=$(wc -l < "$EVENT_LOG")
  [ "$AFTER" -gt "$BEFORE" ]
}

@test "hook exits silently when event log is missing" {
  MISSING_DIR=$(mktemp -d)
  SAGE_PROJECT_DIR="$MISSING_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
  PAYLOAD=$(SESSION_ID="no-log" prompt_payload "no, wrong approach")
  run bash -c "echo '$PAYLOAD' | SAGE_PROJECT_DIR='$MISSING_DIR' bash '$HOOK' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ ! -f "$MISSING_DIR/.sage/events/session-no-log.jsonl" ]
  rm -rf "$MISSING_DIR"
}
