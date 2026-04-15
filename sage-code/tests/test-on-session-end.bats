#!/usr/bin/env bats

load test_helper

HOOK=""
SESSION_ID="end-test-session"
EVENT_LOG=""

setup() {
  setup_sage_env
  HOOK="$SCRIPT_DIR/hooks/scripts/on-session-end.sh"
  export CLAUDE_SESSION_ID="$SESSION_ID"
  init_sage
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"

  # Seed the log with known events:
  # - 1 session_start
  # - 3 tool_outcome (2 success, 1 failure)
  # - 1 correction (negative)
  # - 1 positive_signal
  # - 2 files modified (Write tools with file_path)
  python3 << PYEOF
import json

def ts(offset=0):
    return "2026-04-15T10:00:{:02d}Z".format(offset)

events = [
    {"ts": ts(0),  "type": "session_start",  "session_id": "$SESSION_ID", "branch": "main", "cwd": "/proj", "recent_commits": [], "diff_files": []},
    {"ts": ts(5),  "type": "tool_outcome",   "tool": "Write",  "file_path": "/proj/foo.py", "command": "", "success": True},
    {"ts": ts(10), "type": "tool_outcome",   "tool": "Write",  "file_path": "/proj/bar.py", "command": "", "success": True},
    {"ts": ts(15), "type": "tool_outcome",   "tool": "Bash",   "file_path": "",             "command": "npm test", "success": False},
    {"ts": ts(20), "type": "correction",     "signal": "negative", "excerpt": "no, wrong"},
    {"ts": ts(25), "type": "positive_signal","signal": "positive", "excerpt": "perfect!"},
]
with open("$EVENT_LOG", "w") as f:
    for e in events:
        f.write(json.dumps(e) + "\n")
PYEOF
}

teardown() {
  teardown_sage_env
}

@test "on-session-end appends a session_end event" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  run python3 -c "
import json
last = open('$EVENT_LOG').readlines()[-1]
d = json.loads(last)
print(d.get('type',''))
"
  [ "$status" -eq 0 ]
  [ "$output" = "session_end" ]
}

@test "on-session-end summary has correct tools_used count" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  run python3 -c "
import json
lines = [json.loads(l) for l in open('$EVENT_LOG') if l.strip()]
end = lines[-1]
print(end.get('summary', {}).get('tools_used', 'MISSING'))
"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "on-session-end summary has correct errors count" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  run python3 -c "
import json
lines = [json.loads(l) for l in open('$EVENT_LOG') if l.strip()]
end = lines[-1]
print(end.get('summary', {}).get('errors', 'MISSING'))
"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "on-session-end summary has correct corrections count" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  run python3 -c "
import json
lines = [json.loads(l) for l in open('$EVENT_LOG') if l.strip()]
end = lines[-1]
print(end.get('summary', {}).get('corrections', 'MISSING'))
"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "on-session-end summary has correct positive_signals count" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  run python3 -c "
import json
lines = [json.loads(l) for l in open('$EVENT_LOG') if l.strip()]
end = lines[-1]
print(end.get('summary', {}).get('positive_signals', 'MISSING'))
"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "on-session-end summary has correct files_modified count" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  run python3 -c "
import json
lines = [json.loads(l) for l in open('$EVENT_LOG') if l.strip()]
end = lines[-1]
print(end.get('summary', {}).get('files_modified', 'MISSING'))
"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "on-session-end creates .unprocessed marker file" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  MARKER="$TEST_DIR/.sage/events/session-${SESSION_ID}.unprocessed"
  [ -f "$MARKER" ]
}

@test "on-session-end summary contains non-negative duration_s" {
  SAGE_PROJECT_DIR="$TEST_DIR" CLAUDE_SESSION_ID="$SESSION_ID" bash "$HOOK"
  run python3 -c "
import json
last = open('$EVENT_LOG').readlines()[-1]
d = json.loads(last)
duration = d.get('summary', {}).get('duration_s', None)
if duration is None:
    print('MISSING')
    exit(1)
elif float(duration) >= 0:
    print('ok')
else:
    print('negative')
    exit(1)
"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "hook exits silently when .sage/ directory is missing" {
  EMPTY_DIR=$(mktemp -d)
  run bash -c "SAGE_PROJECT_DIR='$EMPTY_DIR' CLAUDE_SESSION_ID='$SESSION_ID' bash '$HOOK' 2>/dev/null"
  rm -rf "$EMPTY_DIR"
  [ "$status" -eq 0 ]
}

@test "hook exits silently when event log is missing" {
  NO_LOG_DIR=$(mktemp -d)
  SAGE_PROJECT_DIR="$NO_LOG_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
  run bash -c "SAGE_PROJECT_DIR='$NO_LOG_DIR' CLAUDE_SESSION_ID='no-log-session' bash '$HOOK' 2>/dev/null"
  rm -rf "$NO_LOG_DIR"
  [ "$status" -eq 0 ]
}
