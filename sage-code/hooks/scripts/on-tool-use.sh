#!/usr/bin/env bash
set -euo pipefail

# PostToolUse / PostToolUseFailure hook.
# Claude Code sends the event as JSON on stdin. PostToolUse fires only for
# tool calls that succeed; failed calls arrive as PostToolUseFailure.

# ── Environment ────────────────────────────────────────────────────────────
SAGE_PROJECT_DIR="${SAGE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
SAGE_DIR="$SAGE_PROJECT_DIR/.sage"

# ── Exit silently if .sage/ doesn't exist ─────────────────────────────────
[ -d "$SAGE_DIR" ] || exit 0

# ── Read stdin and pass via env to avoid heredoc quoting issues ────────────
export _HOOK_INPUT
_HOOK_INPUT=$(cat)
export _HOOK_SAGE_DIR="$SAGE_DIR"

python3 << 'PYEOF'
import json, re, sys, os
from datetime import datetime, timezone

raw      = os.environ.get("_HOOK_INPUT", "")
sage_dir = os.environ.get("_HOOK_SAGE_DIR", "")

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

# Session ID comes from the hook input; keep it safe for use in a file name
session_id = re.sub(r"[^A-Za-z0-9._-]", "_", str(data.get("session_id") or "unknown"))
event_log  = os.path.join(sage_dir, "events", f"session-{session_id}.jsonl")

# Exit silently if the session was never initialized
if not os.path.isfile(event_log):
    sys.exit(0)

tool_name  = data.get("tool_name", "")
tool_input = data.get("tool_input") or {}

# Read-only and bookkeeping tools: skip without writing any event
SKIP_TOOLS = {
    "Read", "Glob", "Grep", "LSP", "WebSearch", "WebFetch",
    "TodoWrite", "TaskCreate", "TaskGet", "TaskList", "TaskUpdate",
    "TaskOutput", "TaskStop", "AskUserQuestion", "ToolSearch",
    "ListMcpResourcesTool", "ReadMcpResourceTool",
}
if tool_name in SKIP_TOOLS:
    sys.exit(0)

success = data.get("hook_event_name") != "PostToolUseFailure"

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
if not success:
    event["error"] = str(data.get("error", ""))[:300]
    if data.get("is_interrupt"):
        event["interrupted"] = True

with open(event_log, "a") as f:
    f.write(json.dumps(event) + "\n")
PYEOF
