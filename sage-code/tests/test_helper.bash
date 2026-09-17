# Common setup for all SAGE-Code bats tests
SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup_sage_env() {
  TEST_DIR=$(mktemp -d)
  export SAGE_PROJECT_DIR="$TEST_DIR"
  SESSION_ID="${SESSION_ID:-test-session-$$}"
}

teardown_sage_env() {
  rm -rf "$TEST_DIR"
}

init_sage() {
  SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
}

init_sage_with_log() {
  init_sage
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  touch "$EVENT_LOG"
}

# refute_grep <pattern> <file> — fails if a line of the file matches.
# Use this, not `! grep`: bats does not fail a test on a negated command.
refute_grep() {
  if grep -q -- "$1" "$2"; then
    echo "unexpected match for '$1' in $2" >&2
    return 1
  fi
}

# ── Hook input builders ────────────────────────────────────────────────────
# Claude Code sends hook input as JSON on stdin. These helpers print payloads
# in that shape, for the session in $SESSION_ID. Pipe them into a hook script.

_EMPTY_JSON='{}'

# _payload <hook_event_name> [extra fields as a JSON object]
_payload() {
  python3 -c '
import json, sys
event, session_id, cwd, extra = sys.argv[1:5]
data = {
    "session_id": session_id,
    "transcript_path": "/tmp/transcript.jsonl",
    "cwd": cwd,
    "permission_mode": "default",
    "hook_event_name": event,
}
data.update(json.loads(extra))
print(json.dumps(data))
' "$1" "$SESSION_ID" "${TEST_DIR:-/tmp}" "${2:-$_EMPTY_JSON}"
}

# session_start_payload [source]
session_start_payload() {
  _payload SessionStart "{\"source\": \"${1:-startup}\"}"
}

# session_end_payload [reason]
session_end_payload() {
  _payload SessionEnd "{\"reason\": \"${1:-other}\"}"
}

# prompt_payload <prompt text>
prompt_payload() {
  _payload UserPromptSubmit "$(python3 -c 'import json,sys; print(json.dumps({"prompt": sys.argv[1]}))' "$1")"
}

# tool_payload <tool_name> [tool_input JSON] — a tool call that succeeded
tool_payload() {
  _payload PostToolUse "{\"tool_name\": \"$1\", \"tool_input\": ${2:-$_EMPTY_JSON}, \"tool_response\": {}, \"tool_use_id\": \"toolu_test\"}"
}

# tool_failure_payload <tool_name> [tool_input JSON] [error text] — a tool call that failed
tool_failure_payload() {
  _payload PostToolUseFailure "$(python3 -c '
import json, sys
print(json.dumps({
    "tool_name": sys.argv[1],
    "tool_input": json.loads(sys.argv[2]),
    "tool_use_id": "toolu_test",
    "error": sys.argv[3],
    "is_interrupt": False,
}))' "$1" "${2:-$_EMPTY_JSON}" "${3:-Exit code 1}")"
}
