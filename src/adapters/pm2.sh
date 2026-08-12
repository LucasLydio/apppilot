#!/usr/bin/env bash

pm2_process_name() {
  printf 'apppilot-%s' "$APP_NAME"
}

pm2_validate() {
  command -v pm2 >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
}

pm2_start() {
  pm2_validate || return "$?"
  local process_name
  process_name="$(pm2_process_name)"
  (cd "$APP_PATH" && pm2 start "$APP_ENTRYPOINT" --name "$process_name" --update-env)
}

pm2_stop() {
  pm2_validate || return "$?"
  pm2 stop "$(pm2_process_name)"
}

pm2_restart() {
  pm2_validate || return "$?"
  pm2 restart "$(pm2_process_name)" --update-env
}

pm2_status() {
  pm2_validate || return "$?"
  pm2 describe "$(pm2_process_name)" >/dev/null 2>&1
}

pm2_status_text() {
  pm2_validate || return "$?"
  pm2 describe "$(pm2_process_name)" 2>/dev/null | awk -F '│' '/status/ {gsub(/[[:space:]]/, "", $3); print $3; exit}'
}

pm2_status_details() {
  pm2_validate || return "$?"
  local process_name
  process_name="$(pm2_process_name)"

  if command -v node >/dev/null 2>&1; then
    APPPILOT_PM2_PROCESS_NAME="$process_name"
    export APPPILOT_PM2_PROCESS_NAME
    pm2 jlist 2>/dev/null | node -e '
const fs = require("fs");
const name = process.env.APPPILOT_PM2_PROCESS_NAME || "";
let list = [];
try {
  const input = fs.readFileSync(0, "utf8").trim();
  list = input ? JSON.parse(input) : [];
} catch {
  process.exit(1);
}
const app = list.find((item) => item && item.name === name);
const print = (key, value) => {
  const normalized = value == null || value === "" ? "-" : value;
  process.stdout.write(key + "\t" + normalized + "\n");
};
print("runtimeName", name);
if (!app) {
  print("status", "stopped");
  print("pmId", "-");
  print("pid", "-");
  print("cpu", "-");
  print("memoryBytes", "0");
  print("restarts", "0");
  print("uptimeSeconds", "0");
  print("user", "-");
  print("interpreter", "-");
  print("execMode", "-");
  print("scriptPath", "-");
  process.exit(0);
}
const env = app.pm2_env || {};
const monit = app.monit || {};
const uptimeSeconds = env.pm_uptime ? Math.max(0, Math.floor((Date.now() - Number(env.pm_uptime)) / 1000)) : 0;
print("status", env.status || "unknown");
print("pmId", app.pm_id);
print("pid", app.pid || "-");
print("cpu", monit.cpu == null ? "-" : String(monit.cpu) + "%");
print("memoryBytes", monit.memory || 0);
print("restarts", env.restart_time || 0);
print("uptimeSeconds", uptimeSeconds);
print("user", env.username || "-");
print("interpreter", env.exec_interpreter || "-");
print("execMode", env.exec_mode || "-");
print("scriptPath", env.pm_exec_path || "-");
'
    return "$?"
  fi

  local status
  status="$(pm2_status_text || true)"
  [[ -n "$status" ]] || status="stopped"
  printf 'runtimeName\t%s\n' "$process_name"
  printf 'status\t%s\n' "$status"
  printf 'pmId\t-\n'
  printf 'pid\t-\n'
  printf 'cpu\t-\n'
  printf 'memoryBytes\t0\n'
  printf 'restarts\t-\n'
  printf 'uptimeSeconds\t0\n'
  printf 'user\t-\n'
  printf 'interpreter\t-\n'
  printf 'execMode\t-\n'
  printf 'scriptPath\t-\n'
}

pm2_logs() {
  pm2_validate || return "$?"
  pm2 logs "$(pm2_process_name)" --lines "${APPPILOT_LOG_LINES:-80}" --nostream
}
