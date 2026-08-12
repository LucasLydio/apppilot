#!/usr/bin/env bash

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APPPILOT_BIN="$PROJECT_ROOT/bin/apppilot"

setup_apppilot_home() {
  APPPILOT_TEST_HOME="$(mktemp -d)"
  export APPPILOT_CONFIG_HOME="$APPPILOT_TEST_HOME/config"
  export APPPILOT_STATE_HOME="$APPPILOT_TEST_HOME/state"
}

teardown_apppilot_home() {
  rm -rf "${APPPILOT_TEST_HOME:-}"
}
