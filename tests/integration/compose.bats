#!/usr/bin/env bats

load ../test_helper

setup() {
  setup_apppilot_home
  bash "$APPPILOT_BIN" init --non-interactive >/dev/null
}

teardown() {
  if command -v docker >/dev/null 2>&1; then
    docker compose -f "$PROJECT_ROOT/tests/fixtures/compose-app/compose.yaml" -p ecommerce down >/dev/null 2>&1 || true
  fi
  teardown_apppilot_home
}

@test "compose lifecycle works when docker compose is available" {
  command -v docker >/dev/null 2>&1 || skip "docker is not installed"
  docker info >/dev/null 2>&1 || skip "docker daemon is unavailable"
  docker compose version >/dev/null 2>&1 || skip "docker compose is unavailable"
  fixture="$PROJECT_ROOT/tests/fixtures/compose-app"
  run bash "$APPPILOT_BIN" add --name ecommerce --manager compose --path "$fixture" --compose-file compose.yaml --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" start ecommerce --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" status ecommerce
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" restart ecommerce --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" stop ecommerce --non-interactive
  [ "$status" -eq 0 ]
}
