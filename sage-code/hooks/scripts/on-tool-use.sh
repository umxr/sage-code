#!/usr/bin/env bash
set -euo pipefail

# ── Environment ────────────────────────────────────────────────────────────
SAGE_PROJECT_DIR="${SAGE_PROJECT_DIR:-$(pwd)}"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
SAGE_DIR="$SAGE_PROJECT_DIR/.sage"
EVENT_LOG="$SAGE_DIR/events/session-${SESSION_ID}.jsonl"

# ── Exit silently if .sage/ or event log doesn't exist ────────────────────
[ -d "$SAGE_DIR" ]  || exit 0
[ -f "$EVENT_LOG" ] || exit 0

# ── Read stdin and pass via env to avoid heredoc quoting issues ────────────
export _HOOK_INPUT
_HOOK_INPUT=$(cat)
export _HOOK_EVENT_LOG="$EVENT_LOG"

python3 << 'PYEOF'
import json, re, sys, os
from datetime import datetime, timezone

raw        = os.environ.get("_HOOK_INPUT", "")
event_log  = os.environ.get("_HOOK_EVENT_LOG", "")

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

tool_name   = data.get("tool_name", "")
tool_input  = data.get("tool_input", {})
tool_result = data.get("tool_result", "")

# Read-only tools: skip without writing any event
SKIP_TOOLS = {
    "Read", "Glob", "Grep", "WebSearch", "WebFetch",
    "TodoWrite", "AskUserQuestion",
    "ListMcpResourcesTool", "ReadMcpResourceTool",
}
if tool_name in SKIP_TOOLS:
    sys.exit(0)

# Detect success/failure from tool_result text
FAILURE_PATTERNS = [
    r"(?i)\berror\b",
    r"(?i)\bfailed?\b",
    r"(?i)\bexception\b",
    r"(?i)\btraceback\b",
    r"(?i)exit code [1-9]",
    r"(?i)command not found",
    r"(?i)\bno such file\b",
    r"(?i)\bpermission denied\b",
    r"(?i)\bsyntaxerror\b",
]
result_str = str(tool_result)
success    = not any(re.search(p, result_str) for p in FAILURE_PATTERNS)

# Extract relevant path or command
file_path = tool_input.get("file_path", tool_input.get("path", ""))
command   = tool_input.get("command", "")

ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
event = {
    "ts":        ts,
    "type":      "tool_outcome",
    "tool":      tool_name,
    "file_path": file_path,
    "command":   command,
    "success":   success,
}

with open(event_log, "a") as f:
    f.write(json.dumps(event) + "\n")
PYEOF
