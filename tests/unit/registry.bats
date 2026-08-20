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

@test "guided add can create env from env example" {
  project="$APPPILOT_TEST_HOME/env-app"
  mkdir -p "$project"
  cp "$PROJECT_ROOT/tests/fixtures/pm2-app/server.js" "$project/server.js"
  printf 'PORT=3000\nTOKEN=change-me\n' >"$project/.env.example"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash -c '
    printf "%s\n" env-api pm2 "$2" server.js production y y | APPPILOT_FORCE_INTERACTIVE=1 bash "$1" add
  ' _ "$APPPILOT_BIN" "$project"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found .env.example and no .env"* ]]
  [[ "$output" == *"Created .env from .env.example"* ]]
  [ -f "$project/.env" ]
  [ "$(stat -c '%a' "$project/.env")" = "600" ]
}

@test "non-interactive add can create env from env example explicitly" {
  project="$APPPILOT_TEST_HOME/env-app"
  mkdir -p "$project"
  cp "$PROJECT_ROOT/tests/fixtures/pm2-app/server.js" "$project/server.js"
  printf 'PORT=3000\nTOKEN=change-me\n' >"$project/.env.example"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name env-api --manager pm2 --path "$project" --entrypoint server.js --env-from-example --non-interactive
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created .env from .env.example"* ]]
  [ -f "$project/.env" ]
}

@test "env init creates env for registered application" {
  project="$APPPILOT_TEST_HOME/env-app"
  mkdir -p "$project"
  cp "$PROJECT_ROOT/tests/fixtures/pm2-app/server.js" "$project/server.js"
  printf 'PORT=3000\nTOKEN=change-me\n' >"$project/.env.example"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name env-api --manager pm2 --path "$project" --entrypoint server.js --no-env-from-example --non-interactive
  [ "$status" -eq 0 ]
  [ ! -e "$project/.env" ]
  run bash "$APPPILOT_BIN" env init env-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created .env from .env.example"* ]]
  [ -f "$project/.env" ]
}

@test "env init dry-run does not write env file" {
  project="$APPPILOT_TEST_HOME/env-app"
  mkdir -p "$project"
  cp "$PROJECT_ROOT/tests/fixtures/pm2-app/server.js" "$project/server.js"
  printf 'PORT=3000\n' >"$project/.env.example"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name env-api --manager pm2 --path "$project" --entrypoint server.js --no-env-from-example --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" env init env-api --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [ ! -e "$project/.env" ]
}

@test "env init refuses to overwrite existing env file" {
  project="$APPPILOT_TEST_HOME/env-app"
  mkdir -p "$project"
  cp "$PROJECT_ROOT/tests/fixtures/pm2-app/server.js" "$project/server.js"
  printf 'PORT=3000\n' >"$project/.env.example"
  printf 'PORT=4000\n' >"$project/.env"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name env-api --manager pm2 --path "$project" --entrypoint server.js --no-env-from-example --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" env init env-api
  [ "$status" -eq 6 ]
  [[ "$output" == *".env already exists"* ]]
  [ "$(cat "$project/.env")" = "PORT=4000" ]
}

@test "env init supports json output" {
  project="$APPPILOT_TEST_HOME/env-app"
  mkdir -p "$project"
  cp "$PROJECT_ROOT/tests/fixtures/pm2-app/server.js" "$project/server.js"
  printf 'PORT=3000\n' >"$project/.env.example"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name env-api --manager pm2 --path "$project" --entrypoint server.js --no-env-from-example --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" env init env-api --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"created":true'* ]]
}

@test "health reports online runtime" {
  fixture="$PROJECT_ROOT/tests/fixtures/pm2-app"
  fake_bin="$APPPILOT_TEST_HOME/bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\ncase "$1" in jlist) printf "[]";; *) exit 0;; esac\n' >"$fake_bin/pm2"
  printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf "%%b\\n" "runtimeName\\tapppilot-users-api" "status\\tonline" "pmId\\t0" "pid\\t1234" "cpu\\t1%%" "memoryBytes\\t52428800" "restarts\\t0" "uptimeSeconds\\t60" "user\\tlucas" "interpreter\\tnode" "execMode\\tfork" "scriptPath\\t-"\n' >"$fake_bin/node"
  chmod +x "$fake_bin/pm2" "$fake_bin/node"
  PATH="$fake_bin:$PATH"
  export PATH

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$fixture" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" health users-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"AppPilot Health"* ]]
  [[ "$output" == *"Runtime status: online"* ]]
}

@test "backup snapshot archives app without env or node_modules by default" {
  project="$APPPILOT_TEST_HOME/backup-app"
  mkdir -p "$project/node_modules/pkg" "$project/.git"
  printf 'console.log("ok")\n' >"$project/server.js"
  printf 'SECRET=value\n' >"$project/.env"
  printf 'module\n' >"$project/node_modules/pkg/index.js"
  printf 'git\n' >"$project/.git/config"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name backup-api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" backup snapshot backup-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backup snapshot created"* ]]

  snapshot="$(find "$APPPILOT_STATE_HOME/backups/backup-api" -name '*.tar.gz' | head -n 1)"
  [ -f "$snapshot" ]
  listing="$(tar -tzf "$snapshot")"
  [[ "$listing" == *"backup-app/server.js"* ]]
  [[ "$listing" != *"backup-app/.env"* ]]
  [[ "$listing" != *"backup-app/node_modules"* ]]
  [[ "$listing" != *"backup-app/.git"* ]]

  run bash "$APPPILOT_BIN" backup list backup-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"backup-api-"* ]]
}

@test "expose dry-run renders static nginx config" {
  project="$APPPILOT_TEST_HOME/web-app"
  mkdir -p "$project/dist"
  printf 'ok\n' >"$project/dist/index.html"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add-static --name web --path "$project" --build-dir dist --non-interactive
  [ "$status" -eq 0 ]
  [[ "$output" == *"Registered web (static)"* ]]
  run bash "$APPPILOT_BIN" expose web --domain example.com --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would expose: web"* ]]
  [[ "$output" == *"Type: static"* ]]
  [[ "$output" == *"server_name example.com"* ]]
  [[ "$output" == *"root $project/dist"* ]]
  [[ "$output" == *"try_files"* ]]
  [ ! -e "/etc/nginx/sites-available/apppilot-web-example.com.conf" ]
}

@test "add-static supports json output and list shows static manager" {
  project="$APPPILOT_TEST_HOME/web-app"
  mkdir -p "$project/build"
  printf 'ok\n' >"$project/build/index.html"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add-static --name web --path "$project" --build-dir build --json --non-interactive
  [ "$status" -eq 0 ]
  [[ "$output" == *'"manager":"static"'* ]]
  [[ "$output" == *'"buildDir":"build"'* ]]

  run bash "$APPPILOT_BIN" list --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"manager":"static"'* ]]
  [[ "$output" == *'"buildDir":"build"'* ]]
}

@test "expose dry-run renders proxy nginx config json" {
  project="$APPPILOT_TEST_HOME/api-app"
  mkdir -p "$project"
  printf 'console.log("ok")\n' >"$project/server.js"

  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" expose api --domain api.example.com --type proxy --port 3000 --dry-run --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"domain":"api.example.com"'* ]]
  [[ "$output" == *'"type":"proxy"'* ]]
  [[ "$output" == *'"port":"3000"'* ]]
  [[ "$output" == *'"dryRun":true'* ]]
}

setup_fake_deploy_tools() {
  fake_bin="$APPPILOT_TEST_HOME/bin"
  mkdir -p "$fake_bin"
  printf '1111111111111111111111111111111111111111\n' >"$APPPILOT_TEST_HOME/revision"
  cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  rev-parse)
    case "${2:-}" in
      --is-inside-work-tree) printf 'true\n' ;;
      HEAD) cat "$APPPILOT_TEST_HOME/revision" ;;
      *) printf 'true\n' ;;
    esac
    ;;
  status) ;;
  pull)
    printf '2222222222222222222222222222222222222222\n' >"$APPPILOT_TEST_HOME/revision"
    printf 'git pull %s %s\n' "$2" "$3"
    printf 'git pull %s %s\n' "$2" "$3" >>"$APPPILOT_TEST_HOME/order"
    ;;
  reset)
    if [[ "${2:-}" == "--hard" ]]; then
      printf '%s\n' "$3" >"$APPPILOT_TEST_HOME/revision"
      printf 'git reset --hard %s\n' "$3"
      printf 'git reset --hard %s\n' "$3" >>"$APPPILOT_TEST_HOME/order"
    fi
    ;;
  *) printf 'git %s\n' "$*" ;;
esac
EOF
  cat >"$fake_bin/npm" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  ci|install) printf 'npm %s\n' "$1"; printf 'npm %s\n' "$1" >>"$APPPILOT_TEST_HOME/order" ;;
  run)
    printf 'npm run %s\n' "$2"
    printf 'npm run %s\n' "$2" >>"$APPPILOT_TEST_HOME/order"
    if [[ "$2" == "test" && "${FAKE_TEST_FAIL:-0}" == "1" ]]; then
      printf 'tests failed\n' >&2
      exit 1
    fi
    ;;
esac
EOF
  cat >"$fake_bin/pm2" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  restart) printf 'pm2 restart %s\n' "$2"; printf 'pm2 restart %s\n' "$2" >>"$APPPILOT_TEST_HOME/order" ;;
  start) printf 'pm2 start\n'; printf 'pm2 start\n' >>"$APPPILOT_TEST_HOME/order" ;;
  jlist) printf '[]' ;;
  *) ;;
esac
EOF
  cat >"$fake_bin/node" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf "%b\n" "runtimeName\tapppilot-users-api" "status\tonline" "pmId\t0" "pid\t1234" "cpu\t1%" "memoryBytes\t52428800" "restarts\t0" "uptimeSeconds\t60" "user\tlucas" "interpreter\tnode" "execMode\tfork" "scriptPath\t-"
EOF
  chmod +x "$fake_bin/git" "$fake_bin/npm" "$fake_bin/pm2" "$fake_bin/node"
  PATH="$fake_bin:$PATH"
  export PATH
}

create_deploy_app() {
  project="$APPPILOT_TEST_HOME/deploy-app"
  mkdir -p "$project"
  cp "$PROJECT_ROOT/tests/fixtures/pm2-app/server.js" "$project/server.js"
  printf '{"scripts":{"test":"node --test","build":"echo build","start":"node server.js"}}\n' >"$project/package.json"
  printf '{}\n' >"$project/package-lock.json"
}

@test "deploy dry-run plans origin main with tests before build" {
  setup_fake_deploy_tools
  create_deploy_app
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy users-api --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"git pull origin main"* ]]
  [[ "$output" == *"run test script"* ]]
  [[ "$output" == *"run build script"* ]]
  [[ "$output" == *"restart PM2 app"* ]]
}

@test "deploy dry-run supports custom remote and branch json" {
  setup_fake_deploy_tools
  create_deploy_app
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy users-api --remote upstream --branch develop --dry-run --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"remote":"upstream"'* ]]
  [[ "$output" == *'"branch":"develop"'* ]]
  [[ "$output" == *'git pull upstream develop'* ]]
}

@test "deploy runs pull install test build and restart in order" {
  setup_fake_deploy_tools
  create_deploy_app
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy users-api
  [ "$status" -eq 0 ]
  expected=$'git pull origin main\nnpm ci\nnpm run test\nnpm run build\npm2 restart apppilot-users-api'
  [ "$(cat "$APPPILOT_TEST_HOME/order")" = "$expected" ]
}

@test "deploy records success history with before and after revisions" {
  setup_fake_deploy_tools
  create_deploy_app
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy users-api
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy history users-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deploy History"* ]]
  [[ "$output" == *"success"* ]]
  [[ "$output" == *"111111111111"* ]]
  [[ "$output" == *"222222222222"* ]]
  [[ "$output" == *"complete"* ]]
}

@test "deploy rollback dry-run targets latest previous revision" {
  setup_fake_deploy_tools
  create_deploy_app
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy users-api
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy rollback users-api --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would rollback: users-api"* ]]
  [[ "$output" == *"Current: 222222222222"* ]]
  [[ "$output" == *"Target:  111111111111"* ]]
  [[ "$output" == *"git reset --hard 1111111111111111111111111111111111111111"* ]]
}

@test "deploy rollback resets revision and restarts app" {
  setup_fake_deploy_tools
  create_deploy_app
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy users-api
  [ "$status" -eq 0 ]
  : >"$APPPILOT_TEST_HOME/order"
  run bash "$APPPILOT_BIN" deploy rollback users-api
  [ "$status" -eq 0 ]
  expected=$'git reset --hard 1111111111111111111111111111111111111111\npm2 restart apppilot-users-api'
  [ "$(cat "$APPPILOT_TEST_HOME/order")" = "$expected" ]
  [ "$(cat "$APPPILOT_TEST_HOME/revision")" = "1111111111111111111111111111111111111111" ]
}

@test "deploy stops before build when tests fail" {
  setup_fake_deploy_tools
  create_deploy_app
  export FAKE_TEST_FAIL=1
  run bash "$APPPILOT_BIN" init --non-interactive --quiet
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" add --name users-api --manager pm2 --path "$project" --entrypoint server.js --non-interactive
  [ "$status" -eq 0 ]
  run bash "$APPPILOT_BIN" deploy users-api
  [ "$status" -eq 1 ]
  [[ "$output" == *"Test script failed"* ]]
  [[ "$(cat "$APPPILOT_TEST_HOME/order")" != *"npm run build"* ]]
  [[ "$(cat "$APPPILOT_TEST_HOME/order")" != *"pm2 restart"* ]]
  run bash "$APPPILOT_BIN" deploy history users-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"failed"* ]]
  [[ "$output" == *"test"* ]]
  unset FAKE_TEST_FAIL
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
  printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf "%%b\\n" "runtimeName\\tapppilot-users-api" "status\\tonline" "pmId\\t0" "pid\\t1234" "cpu\\t1%%" "memoryBytes\\t52428800" "restarts\\t2" "uptimeSeconds\\t3660" "user\\tlucas" "interpreter\\tnode" "execMode\\tfork" "scriptPath\\t$PWD/tests/fixtures/pm2-app/server.js"\n' >"$fake_bin/node"
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
  [[ "$output" == *"Name"*"Manager"*"Status"* ]]
  [[ "$output" == *"users-api"*"pm2"*"online"* ]]
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
