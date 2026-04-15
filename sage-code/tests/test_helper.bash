# Common setup for all SAGE-Code bats tests
SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup_sage_env() {
  TEST_DIR=$(mktemp -d)
  export SAGE_PROJECT_DIR="$TEST_DIR"
  export CLAUDE_SESSION_ID="test-session-$$"
}

teardown_sage_env() {
  rm -rf "$TEST_DIR"
}

init_sage() {
  SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
}

init_sage_with_log() {
  init_sage
  EVENT_LOG="$TEST_DIR/.sage/events/session-${CLAUDE_SESSION_ID}.jsonl"
  touch "$EVENT_LOG"
}
