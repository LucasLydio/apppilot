#!/usr/bin/env bats

load ../test_helper

@test "version prints v0.1.0" {
  run bash "$APPPILOT_BIN" --version
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.0" ]
}

@test "help prints command list" {
  run bash "$APPPILOT_BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"AppPilot 0.1.0"* ]]
  [[ "$output" == *"security audit"* ]]
  [[ "$output" == *"validate"* ]]
  [[ "$output" == *"overview"* ]]
}

@test "unknown command returns stable invalid-argument exit code" {
  run bash "$APPPILOT_BIN" nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown command"* ]]
}

@test "unknown command returns JSON error when requested" {
  run bash "$APPPILOT_BIN" --json nope
  [ "$status" -eq 2 ]
  [[ "$output" == '{"success":false'* ]]
}

@test "list json has valid success envelope" {
  setup_apppilot_home
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" list --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"data":{"apps":[]}'* ]]
  [[ "$output" != *'}},"warnings"'* ]]
  teardown_apppilot_home
}

@test "overview renders human summary" {
  setup_apppilot_home
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" overview
  [ "$status" -eq 0 ]
  [[ "$output" == *"AppPilot"* ]]
  [[ "$output" == *"Adapters"* ]]
  teardown_apppilot_home
}

@test "overview supports json" {
  setup_apppilot_home
  run bash "$APPPILOT_BIN" init --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" overview --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"appCount"'* ]]
  [[ "$output" == *'"adapters"'* ]]
  teardown_apppilot_home
}

@test "adapters list returns built-in adapters" {
  run bash "$APPPILOT_BIN" adapters list
  [ "$status" -eq 0 ]
  [[ "$output" == *"pm2"* ]]
  [[ "$output" == *"compose"* ]]
}

@test "adapters list supports json" {
  run bash "$APPPILOT_BIN" adapters list --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"adapters"'* ]]
  [[ "$output" == *'"name":"pm2"'* ]]
  [[ "$output" == *'"name":"compose"'* ]]
}

@test "adapters install supports dry run" {
  run bash "$APPPILOT_BIN" adapters install pm2 --dry-run --non-interactive
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"pm2"* ]]
}

@test "adapters install non-interactive requires yes" {
  run bash "$APPPILOT_BIN" adapters install pm2 --non-interactive
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires --yes"* ]]
}

@test "adapters updates supports json" {
  run bash "$APPPILOT_BIN" adapters updates --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"pm2"'* ]]
  [[ "$output" == *'"compose"'* ]]
}

@test "validate reports uninitialized config" {
  setup_apppilot_home
  run bash "$APPPILOT_BIN" validate
  [ "$status" -eq 6 ]
  [[ "$output" == *"has not been initialized"* ]]
  teardown_apppilot_home
}
