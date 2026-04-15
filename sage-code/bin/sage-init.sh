#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${SAGE_PROJECT_DIR:-$(pwd)}"
SAGE_DIR="$PROJECT_DIR/.sage"

mkdir -p "$SAGE_DIR/events"
mkdir -p "$SAGE_DIR/knowledge"
mkdir -p "$SAGE_DIR/meta"

for category in pitfalls strategies preferences architecture conventions; do
  KNOWLEDGE_FILE="$SAGE_DIR/knowledge/$category.md"
  if [ ! -f "$KNOWLEDGE_FILE" ]; then
    TITLE="$(echo "${category:0:1}" | tr '[:lower:]' '[:upper:]')${category:1}"
    cat > "$KNOWLEDGE_FILE" << MKEOF
# ${TITLE}

<!-- Auto-managed by sage-code. Manual edits are preserved during merges. -->
MKEOF
  fi
done

if [ ! -f "$SAGE_DIR/meta/config.json" ]; then
  cp "$SCRIPT_DIR/templates/config-default.json" "$SAGE_DIR/meta/config.json"
fi

if [ ! -f "$SAGE_DIR/meta/scores.json" ]; then
  echo '[]' > "$SAGE_DIR/meta/scores.json"
fi

if [ ! -f "$SAGE_DIR/meta/history.json" ]; then
  echo '[]' > "$SAGE_DIR/meta/history.json"
fi

if [ ! -f "$SAGE_DIR/meta/archive.md" ]; then
  cat > "$SAGE_DIR/meta/archive.md" << 'MKEOF'
# Archived Heuristics

<!-- Pruned heuristics are preserved here for audit trail. -->
MKEOF
fi

if [ ! -f "$SAGE_DIR/.gitignore" ]; then
  cp "$SCRIPT_DIR/templates/gitignore-template" "$SAGE_DIR/.gitignore"
fi

if [ ! -f "$SAGE_DIR/README.md" ]; then
  cat > "$SAGE_DIR/README.md" << 'MKEOF'
# SAGE-Code Knowledge Base

This directory is managed by the [sage-code](https://github.com/sage-code/sage-code) plugin.

**Sessions analyzed:** 0
**Heuristics learned:** 0

## Knowledge Categories

- `knowledge/pitfalls.md` — Errors and anti-patterns to avoid
- `knowledge/strategies.md` — Proven effective approaches
- `knowledge/preferences.md` — User style and preferences
- `knowledge/architecture.md` — Project architecture knowledge
- `knowledge/conventions.md` — Coding conventions

## How it works

SAGE captures session events, reflects on them, and builds project-specific
knowledge that improves Claude's performance over time. See the plugin README
for details.
MKEOF
fi
