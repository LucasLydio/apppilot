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

compose_logs() {
  compose_validate || return "$?"
  docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" logs --tail "${APPPILOT_LOG_LINES:-80}"
}
