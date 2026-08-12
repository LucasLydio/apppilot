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

@test "guided add registers pm2 application after confirmation" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash -c '
    printf "%s\n" guided-api pm2 "$2" server.js production y | APPPILOT_FORCE_INTERACTIVE=1 bash "$1" add
  ' _ "$APPPILOT_BIN" "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Review Application"* ]]
  [[ "$output" == *"Registered guided-api"* ]]
  [ -f "$APPPILOT_CONFIG_HOME/apps/guided-api.yml" ]
}

@test "guided add can redo answers before writing" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash -c '
    printf "%s\n" wrong-api pm2 "$2" server.js production r guided-api pm2 "$2" server.js production y | APPPILOT_FORCE_INTERACTIVE=1 bash "$1" add
  ' _ "$APPPILOT_BIN" "$fixture"
  [ "$status" -eq 0 ]
  [ ! -f "$APPPILOT_CONFIG_HOME/apps/wrong-api.yml" ]
  [ -f "$APPPILOT_CONFIG_HOME/apps/guided-api.yml" ]
}

@test "guided add gives tips and retries invalid path" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash -c '
    printf "%s\n" guided-api pm2 r "$2" server.js production y | APPPILOT_FORCE_INTERACTIVE=1 bash "$1" add
  ' _ "$APPPILOT_BIN" "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Use the absolute path to the project folder"* ]]
  [[ "$output" == *"Path must be an absolute path"* ]]
  [[ "$output" == *"Registered guided-api"* ]]
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

@test "status renders pm2-style summary table" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  fake_bin="$APPPILOT_TEST_HOME/bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\ncase "$1" in jlist) printf "[]";; *) exit 0;; esac\n' >"$fake_bin/pm2"
  printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf "%%b\\n" "runtimeName\\tapppilot-users-api" "status\\tonline" "pmId\\t0" "pid\\t1234" "cpu\\t1%" "memoryBytes\\t52428800" "restarts\\t2" "uptimeSeconds\\t3660" "user\\tlucas" "interpreter\\tnode" "execMode\\tfork" "scriptPath\\t$PWD/tests/fixtures/pm2-app/server.js"\n' >"$fake_bin/node"
  chmod +x "$fake_bin/pm2" "$fake_bin/node"
  PATH="$fake_bin:$PATH"
  export PATH

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" status users-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"AppPilot Status"* ]]
  [[ "$output" == *"online"* ]]
  [[ "$output" == *"50.0M"* ]]
  [[ "$output" == *"server.js"* ]]
}

@test "status full renders detailed pm2 fields" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  fake_bin="$APPPILOT_TEST_HOME/bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\ncase "$1" in jlist) printf "[]";; *) exit 0;; esac\n' >"$fake_bin/pm2"
  printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf "%%b\\n" "runtimeName\\tapppilot-users-api" "status\\tstopped" "pmId\\t-" "pid\\t-" "cpu\\t-" "memoryBytes\\t0" "restarts\\t0" "uptimeSeconds\\t0" "user\\t-" "interpreter\\tnode" "execMode\\tfork" "scriptPath\\t-"\n' >"$fake_bin/node"
  chmod +x "$fake_bin/pm2" "$fake_bin/node"
  PATH="$fake_bin:$PATH"
  export PATH

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" status --full users-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status"* ]]
  [[ "$output" == *"stopped"* ]]
  [[ "$output" == *"Runtime name"* ]]
  [[ "$output" == *"Config file"* ]]
}
