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

pm2_logs() {
  pm2_validate || return "$?"
  pm2 logs "$(pm2_process_name)" --lines "${APPPILOT_LOG_LINES:-80}" --nostream
}
