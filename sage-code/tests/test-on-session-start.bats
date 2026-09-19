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
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
  [ -f "$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl" ]
}

@test "on-session-start first event has type session_start" {
  SESSION_ID="test-session-001"
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  run python3 -c "import sys,json; d=json.loads(open('$EVENT_LOG').readline()); print(d.get('type',''))"
  [ "$status" -eq 0 ]
  [ "$output" = "session_start" ]
}

@test "on-session-start event contains all required fields" {
  SESSION_ID="test-session-001"
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
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

@test "on-session-start is silent when there is nothing to replay" {
  SESSION_ID="test-session-002"
  OUTPUT=$(session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK")
  [ -z "$OUTPUT" ]
}

@test "on-session-start returns additionalContext when a reflection is pending" {
  init_sage
  touch "$TEST_DIR/.sage/events/session-earlier.unprocessed"
  SESSION_ID="test-session-002"
  CONTEXT=$(session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" | python3 -c "
import sys, json
out = json.load(sys.stdin)['hookSpecificOutput']
assert out['hookEventName'] == 'SessionStart'
print(out['additionalContext'])
")
  [[ "$CONTEXT" == *"1 earlier session log(s)"* ]]
  [[ "$CONTEXT" == *"sage-code:sage-replay"* ]]
}

@test "on-session-start is silent when heuristics exist but Claude has no task" {
  init_sage
  printf '\n### ALWAYS use const\n- **Confidence:** low (1 observation)\n- **Rule:** Use const.\n' >> "$TEST_DIR/.sage/knowledge/conventions.md"
  SESSION_ID="test-session-002"
  OUTPUT=$(session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK")
  [ -z "$OUTPUT" ]
}

@test "on-session-start does not count the marker of its own session as pending" {
  init_sage
  SESSION_ID="test-session-002"
  touch "$TEST_DIR/.sage/events/session-${SESSION_ID}.unprocessed"
  OUTPUT=$(session_start_payload resume | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK")
  [ -z "$OUTPUT" ]
}

@test "on-session-start returns additionalContext when meta-evaluation is due" {
  init_sage
  python3 - "$TEST_DIR/.sage/meta/config.json" <<'PY2'
import json, sys
cfg = json.load(open(sys.argv[1]))
cfg["sessions_since_eval"] = 9
cfg["meta_eval_interval_sessions"] = 10
json.dump(cfg, open(sys.argv[1], "w"), indent=2)
PY2
  SESSION_ID="test-session-002"
  CONTEXT=$(session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" | python3 -c "
import sys, json
print(json.load(sys.stdin)['hookSpecificOutput']['additionalContext'])
")
  [[ "$CONTEXT" == *"Meta-evaluation is due: 10 sessions"* ]]
  [[ "$CONTEXT" == *"sage-code:sage-meta"* ]]
}

@test "on-session-start writes session_start when a rule_loaded event came first" {
  init_sage
  SESSION_ID="test-session-005"
  LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  echo '{"ts":"2026-09-17T10:00:00Z","type":"rule_loaded","rule_id":"pitfall-x","load_reason":"session_start","trigger_file":""}' > "$LOG"
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
  TYPES=$(python3 -c "
import json
print(' '.join(sorted(json.loads(l)['type'] for l in open('$LOG'))))
")
  [ "$TYPES" = "rule_loaded session_start" ]
  COUNT=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.sage/meta/config.json'))['sessions_since_eval'])")
  [ "$COUNT" -eq 1 ]
}

@test "on-session-start on resume does not repeat session_start or the session count" {
  SESSION_ID="test-session-003"
  session_start_payload startup | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
  session_start_payload resume  | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
  session_start_payload compact | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null

  LINES=$(wc -l < "$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl" | tr -d ' ')
  [ "$LINES" -eq 1 ]
  COUNT=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.sage/meta/config.json'))['sessions_since_eval'])")
  [ "$COUNT" -eq 1 ]
}

@test "on-session-start keeps the session ID safe for use in a file name" {
  SESSION_ID="../../evil id"
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
  [ -f "$TEST_DIR/.sage/events/session-.._.._evil_id.jsonl" ]
}

@test "on-session-start increments sessions_since_eval" {
  SESSION_ID="test-session-001"
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
  BEFORE=$(python3 -c "import json; d=json.load(open('$TEST_DIR/.sage/meta/config.json')); print(d['sessions_since_eval'])")

  SESSION_ID="test-session-002"
  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
  AFTER=$(python3 -c "import json; d=json.load(open('$TEST_DIR/.sage/meta/config.json')); print(d['sessions_since_eval'])")

  [ "$AFTER" -gt "$BEFORE" ]
}

@test "on-session-start captures the session when config.json is damaged" {
  init_sage
  SESSION_ID="test-session-006"
  CONFIG="$TEST_DIR/.sage/meta/config.json"
  printf '<<<<<<< HEAD\n{"stale_days": 30}\n=======\n{"stale_days": 60}\n>>>>>>> other\n' > "$CONFIG"
  cp "$CONFIG" "$TEST_DIR/config.before"
  PAYLOAD=$(session_start_payload)
  run bash -c "echo '$PAYLOAD' | SAGE_PROJECT_DIR='$TEST_DIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  TYPE=$(python3 -c "import json; print(json.loads(open('$LOG').readline())['type'])")
  [ "$TYPE" = "session_start" ]
  cmp "$CONFIG" "$TEST_DIR/config.before"
}

@test "on-session-start handles non-git directory gracefully" {
  NON_GIT_DIR=$(mktemp -d)
  SESSION_ID="test-session-004"
  PAYLOAD=$(session_start_payload)
  run bash -c "echo '$PAYLOAD' | SAGE_PROJECT_DIR='$NON_GIT_DIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -f "$NON_GIT_DIR/.sage/events/session-${SESSION_ID}.jsonl" ]
  rm -rf "$NON_GIT_DIR"
}
