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

@test "init renders welcome in human mode" {
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  [[ "$output" == *"DevOps control for Linux VPS applications"* ]]
  [[ "$output" == *"Contribute"* ]]
}

@test "init quiet mode suppresses welcome" {
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
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

@test "add rejects unsafe application names" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name '../bad' --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 2 ]
  [ ! -e "$APPPILOT_CONFIG_HOME/apps/../bad.yml" ]
}

@test "add rejects duplicate application names" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 6 ]
}

@test "add rejects invalid manager" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager systemd --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 2 ]
}

@test "add rejects path traversal in entrypoint" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint ../server.js --non-interactive
  [ "$status" -eq 6 ]
}

@test "validate detects tampered registry file" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  sed -i 's/name: users-api/name: other-app/' "$APPPILOT_CONFIG_HOME/apps/users-api.yml"
  run bash "$APPPILOT_BIN" validate
  [ "$status" -eq 6 ]
  [[ "$output" == *"Application config invalid"* ]]
}

@test "dry-run add validates but does not write registry file" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --dry-run --non-interactive
  [ "$status" -eq 0 ]
  [ ! -e "$APPPILOT_CONFIG_HOME/apps/users-api.yml" ]
}

@test "validate supports json output" {
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" validate --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"checks"'* ]]
}
