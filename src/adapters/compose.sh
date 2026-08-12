#!/usr/bin/env bash

compose_validate() {
  command -v docker >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
  docker info >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
  docker compose version >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
}

compose_args() {
  printf '%s\0' compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME"
}

compose_start() {
  compose_validate || return "$?"
  docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" up -d
}

compose_stop() {
  compose_validate || return "$?"
  docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" stop
}

compose_restart() {
  compose_validate || return "$?"
  docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" restart
}

compose_status() {
  compose_validate || return "$?"
  docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" ps
}

compose_status_details() {
  compose_validate || return "$?"
  local total running status
  total="$(docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" ps --services 2>/dev/null | wc -l | tr -d '[:space:]')"
  running="$(docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" ps --status running --services 2>/dev/null | wc -l | tr -d '[:space:]')"
  [[ -n "$total" ]] || total=0
  [[ -n "$running" ]] || running=0

  if [[ "$total" -eq 0 ]]; then
    status="stopped"
  elif [[ "$running" -eq "$total" ]]; then
    status="online"
  elif [[ "$running" -gt 0 ]]; then
    status="partial"
  else
    status="stopped"
  fi

  printf 'runtimeName\t%s\n' "$APP_NAME"
  printf 'status\t%s\n' "$status"
  printf 'services\t%s/%s\n' "$running" "$total"
  printf 'composeFile\t%s\n' "$APP_COMPOSE_FILE"
  printf 'project\t%s\n' "$APP_NAME"
}

compose_logs() {
  compose_validate || return "$?"
  docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" logs --tail "${APPPILOT_LOG_LINES:-80}"
}
