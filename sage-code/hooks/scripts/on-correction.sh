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

raw       = os.environ.get("_HOOK_INPUT", "")
event_log = os.environ.get("_HOOK_EVENT_LOG", "")

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

user_input = data.get("user_input", "")

# Skip messages shorter than 5 characters
if len(user_input.strip()) < 5:
    sys.exit(0)

text = user_input.strip()

# ── Negative (correction) patterns ────────────────────────────────────────
NEGATIVE_PATTERNS = [
    r"^no[,.\s]",
    r"^don'?t\b",
    r"^stop\b",
    r"^wrong\b",
    r"\bactually\b",
    r"\binstead\b",
    r"\bnot that\b",
    r"^that'?s\s+(wrong|incorrect)\b",
    r"^never\b",
    r"^always\b",
    r"\bremember:",
]

# ── Positive (affirmation) patterns ───────────────────────────────────────
POSITIVE_PATTERNS = [
    r"^(perfect|exactly|great|awesome|nice)\b",
    r"^yes[\s,!.]+.*(right|correct|exactly)\b",
    r"that'?s\s+(perfect|exactly|correct|right)\b",
    r"^good\s+(job|work|call)\b",
]

flags = re.IGNORECASE

is_negative = any(re.search(p, text, flags) for p in NEGATIVE_PATTERNS)
is_positive = any(re.search(p, text, flags) for p in POSITIVE_PATTERNS)

# Negative takes precedence if both match somehow
if not is_negative and not is_positive:
    sys.exit(0)

ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

if is_negative:
    event = {
        "ts":      ts,
        "type":    "correction",
        "signal":  "negative",
        "excerpt": text[:200],
    }
else:
    event = {
        "ts":      ts,
        "type":    "positive_signal",
        "signal":  "positive",
        "excerpt": text[:200],
    }

with open(event_log, "a") as f:
    f.write(json.dumps(event) + "\n")
PYEOF
