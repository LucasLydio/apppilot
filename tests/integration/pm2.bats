#!/usr/bin/env bats

load ../test_helper.bash

setup() {
  setup_apppilot_home
  bash "$APPPILOT_BIN" init --non-interactive >/dev/null
}

teardown() {
  if command -v pm2 >/dev/null 2>&1; then
    pm2 delete apppilot-pm2-fixture >/dev/null 2>&1 || true
    pm2 delete apppilot-users-api >/dev/null 2>&1 || true
  fi
  teardown_apppilot_home
}

@test "pm2 lifecycle works when pm2 is installed" {
  command -v pm2 >/dev/null 2>&1 || skip "pm2 is not installed"
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" start users-api --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" status users-api
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" restart users-api --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" stop users-api --non-interactive
  [ "$status" -eq 0 ]
}
