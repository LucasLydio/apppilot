#!/usr/bin/env bats

load ../test_helper

setup() {
  setup_apppilot_home
}

teardown() {
  teardown_apppilot_home
}

@test "init is idempotent" {
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  [ -f "$APPPILOT_CONFIG_HOME/apppilot.yml" ]
}

@test "add, list, and remove pm2 application" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"users-api"* ]]
  run bash "$APPPILOT_BIN" remove users-api --yes --non-interactive
  [ "$status" -eq 0 ]
}

@test "list json has stable envelope" {
  fixture="$PROJECT_ROOT/tests/fixtures/compose-app"
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name ecommerce --manager compose --path "$fixture" --compose-file compose.yaml --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" list --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"success":true'* ]]
  [[ "$output" == *'"manager":"compose"'* ]]
}

@test "dry-run init does not write configuration" {
  run bash "$APPPILOT_BIN" init --dry-run --non-interactive
  [ "$status" -eq 0 ]
  [ ! -e "$APPPILOT_CONFIG_HOME/apppilot.yml" ]
}
