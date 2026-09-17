#!/usr/bin/env bash
set -euo pipefail

if ! command -v bats > /dev/null 2>&1; then
  echo "bats is not installed. See https://bats-core.readthedocs.io/en/stable/installation.html" >&2
  exit 1
fi

exec bats "$(cd "$(dirname "$0")" && pwd)"/*.bats
