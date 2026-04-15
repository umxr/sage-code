#!/usr/bin/env bats

load test_helper

setup() {
  setup_sage_env
}

teardown() {
  teardown_sage_env
}

@test "sage-init creates .sage directory" {
  init_sage
  [ -d "$TEST_DIR/.sage" ]
}

@test "sage-init creates .sage/events directory" {
  init_sage
  [ -d "$TEST_DIR/.sage/events" ]
}

@test "sage-init creates .sage/knowledge directory" {
  init_sage
  [ -d "$TEST_DIR/.sage/knowledge" ]
}

@test "sage-init creates .sage/meta directory" {
  init_sage
  [ -d "$TEST_DIR/.sage/meta" ]
}

@test "sage-init creates .sage/knowledge/pitfalls.md" {
  init_sage
  [ -f "$TEST_DIR/.sage/knowledge/pitfalls.md" ]
}

@test "sage-init creates .sage/knowledge/strategies.md" {
  init_sage
  [ -f "$TEST_DIR/.sage/knowledge/strategies.md" ]
}

@test "sage-init creates .sage/knowledge/preferences.md" {
  init_sage
  [ -f "$TEST_DIR/.sage/knowledge/preferences.md" ]
}

@test "sage-init creates .sage/knowledge/architecture.md" {
  init_sage
  [ -f "$TEST_DIR/.sage/knowledge/architecture.md" ]
}

@test "sage-init creates .sage/knowledge/conventions.md" {
  init_sage
  [ -f "$TEST_DIR/.sage/knowledge/conventions.md" ]
}

@test "sage-init creates .sage/meta/config.json" {
  init_sage
  [ -f "$TEST_DIR/.sage/meta/config.json" ]
}

@test "sage-init creates .sage/.gitignore" {
  init_sage
  [ -f "$TEST_DIR/.sage/.gitignore" ]
}

@test "sage-init creates .sage/README.md" {
  init_sage
  [ -f "$TEST_DIR/.sage/README.md" ]
}

@test "sage-init is idempotent" {
  init_sage
  run bash "$SCRIPT_DIR/bin/sage-init.sh"
  [ "$status" -eq 0 ]
}
