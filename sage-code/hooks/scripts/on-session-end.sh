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

export _HOOK_EVENT_LOG="$EVENT_LOG"
export _HOOK_SESSION_ID="$SESSION_ID"

python3 << 'PYEOF'
import json, sys, os
from datetime import datetime, timezone

event_log  = os.environ.get("_HOOK_EVENT_LOG", "")
session_id = os.environ.get("_HOOK_SESSION_ID", "unknown")

# ── Read all existing events ───────────────────────────────────────────────
events = []
with open(event_log) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass

# ── Compute summary ────────────────────────────────────────────────────────
tools_used       = sum(1 for e in events if e.get("type") == "tool_outcome")
errors           = sum(1 for e in events if e.get("type") == "tool_outcome" and not e.get("success", True))
corrections      = sum(1 for e in events if e.get("type") == "correction"      and e.get("signal") == "negative")
positive_signals = sum(1 for e in events if e.get("type") == "positive_signal" and e.get("signal") == "positive")

# Count unique non-empty file_paths from tool_outcome events
files_modified = len({
    e["file_path"]
    for e in events
    if e.get("type") == "tool_outcome" and e.get("file_path", "")
})

# Duration: difference between first and last event timestamp
def parse_ts(ts_str):
    try:
        return datetime.strptime(ts_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return None

timestamps = [parse_ts(e.get("ts", "")) for e in events]
timestamps = [t for t in timestamps if t is not None]
if len(timestamps) >= 2:
    duration_s = (max(timestamps) - min(timestamps)).total_seconds()
else:
    duration_s = 0.0

ts_now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

session_end_event = {
    "ts":         ts_now,
    "type":       "session_end",
    "session_id": session_id,
    "summary": {
        "tools_used":       tools_used,
        "errors":           errors,
        "corrections":      corrections,
        "positive_signals": positive_signals,
        "files_modified":   files_modified,
        "duration_s":       duration_s,
    },
}

with open(event_log, "a") as f:
    f.write(json.dumps(session_end_event) + "\n")

# ── Create .unprocessed marker ────────────────────────────────────────────
marker = event_log.replace(".jsonl", ".unprocessed")
with open(marker, "w") as f:
    f.write("")
PYEOF
