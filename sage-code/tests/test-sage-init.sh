#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

echo "=== Test: sage-init.sh creates .sage/ directory structure ==="

SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"

PASS=true
for dir in ".sage" ".sage/events" ".sage/knowledge" ".sage/meta"; do
  if [ ! -d "$TEST_DIR/$dir" ]; then
    echo "FAIL: $dir not created"
    PASS=false
  fi
done

for f in pitfalls.md strategies.md preferences.md architecture.md conventions.md; do
  if [ ! -f "$TEST_DIR/.sage/knowledge/$f" ]; then
    echo "FAIL: .sage/knowledge/$f not created"
    PASS=false
  fi
done

if [ ! -f "$TEST_DIR/.sage/meta/config.json" ]; then
  echo "FAIL: .sage/meta/config.json not created"
  PASS=false
fi

if [ ! -f "$TEST_DIR/.sage/.gitignore" ]; then
  echo "FAIL: .sage/.gitignore not created"
  PASS=false
fi

if [ ! -f "$TEST_DIR/.sage/README.md" ]; then
  echo "FAIL: .sage/README.md not created"
  PASS=false
fi

# Verify idempotency
SAGE_PROJECT_DIR="$TEST_DIR" bash "$SCRIPT_DIR/bin/sage-init.sh"
if [ $? -ne 0 ]; then
  echo "FAIL: sage-init.sh not idempotent"
  PASS=false
fi

if $PASS; then
  echo "PASS: All sage-init.sh checks passed"
else
  echo "FAIL: Some checks failed"
  exit 1
fi
