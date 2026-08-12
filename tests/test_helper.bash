#!/usr/bin/env bash

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APPPILOT_BIN="$PROJECT_ROOT/bin/apppilot"
export PROJECT_ROOT APPPILOT_BIN

setup_apppilot_home() {
  APPPILOT_TEST_HOME="$(mktemp -d)"
  export APPPILOT_CONFIG_HOME="$APPPILOT_TEST_HOME/config"
  export APPPILOT_STATE_HOME="$APPPILOT_TEST_HOME/state"
  export APPPILOT_TEST_HOME
}

teardown_apppilot_home() {
  if [[ -n "${APPPILOT_TEST_HOME:-}" && "$APPPILOT_TEST_HOME" == /tmp/* ]]; then
    rm -rf "$APPPILOT_TEST_HOME"
  fi
  unset APPPILOT_TEST_HOME APPPILOT_CONFIG_HOME APPPILOT_STATE_HOME
  return 0
}
