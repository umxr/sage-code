#!/usr/bin/env bash
set -euo pipefail

# InstructionsLoaded hook.
# Claude Code sends the event as JSON on stdin each time it loads a CLAUDE.md
# or .claude/rules/*.md file. This hook records the loads of the rule files
# that sage-publish-rules wrote, so that the meta-evaluator knows which rules
# were in context in which session.

# ── Environment ────────────────────────────────────────────────────────────
SAGE_PROJECT_DIR="${SAGE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
SAGE_DIR="$SAGE_PROJECT_DIR/.sage"

# ── Exit silently if .sage/events/ doesn't exist ──────────────────────────
[ -d "$SAGE_DIR/events" ] || exit 0

# ── Read stdin and pass via env to avoid heredoc quoting issues ────────────
export _HOOK_INPUT
_HOOK_INPUT=$(cat)
export _HOOK_SAGE_DIR="$SAGE_DIR"
export _HOOK_PROJECT_DIR="$SAGE_PROJECT_DIR"

python3 << 'PYEOF'
import json, re, sys, os
from datetime import datetime, timezone

raw      = os.environ.get("_HOOK_INPUT", "")
sage_dir = os.environ.get("_HOOK_SAGE_DIR", "")
project  = os.path.realpath(os.environ.get("_HOOK_PROJECT_DIR", ""))

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

# Only the *.md files directly in .claude/rules/sage/ are sage rules
file_path = os.path.realpath(str(data.get("file_path") or ""))
rules_dir = os.path.join(project, ".claude", "rules", "sage")
if os.path.dirname(file_path) != rules_dir or not file_path.endswith(".md"):
    sys.exit(0)

# After compaction Claude Code loads the files again; do not count a rule two times
load_reason = data.get("load_reason", "")
if load_reason == "compact":
    sys.exit(0)

# Session ID comes from the hook input; keep it safe for use in a file name
session_id = re.sub(r"[^A-Za-z0-9._-]", "_", str(data.get("session_id") or "unknown"))
event_log  = os.path.join(sage_dir, "events", f"session-{session_id}.jsonl")

# The trigger file is relative to the project when it is in the project
trigger = str(data.get("trigger_file_path") or "")
if trigger:
    real = os.path.realpath(trigger)
    if real.startswith(project + os.sep):
        trigger = os.path.relpath(real, project)

event = {
    "ts":           datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "type":         "rule_loaded",
    "rule_id":      os.path.basename(file_path)[:-len(".md")],
    "load_reason":  load_reason,
    "trigger_file": trigger,
}

# Rules with no path scope load while the SessionStart hook still runs, so
# the log may not exist yet. Opening for append creates it.
with open(event_log, "a") as f:
    f.write(json.dumps(event) + "\n")
PYEOF
