#!/usr/bin/env bash

app_config_file_for() {
  local name="$1"
  printf '%s/%s.yml' "$APPPILOT_APPS_DIR" "$name"
}

app_config_reset() {
  APP_NAME=""
  APP_MANAGER=""
  APP_PATH=""
  APP_ENTRYPOINT=""
  APP_COMPOSE_FILE=""
  APP_ENVIRONMENT=""
}

app_config_load_file() {
  local file="$1"
  local key value
  app_config_reset
  [[ -f "$file" ]] || return "$APPPILOT_ERR_APP_NOT_FOUND"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" == *:* ]] || continue
    key="${line%%:*}"
    value="${line#*:}"
    key="${key//[[:space:]]/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    case "$key" in
      name) APP_NAME="$value" ;;
      manager) APP_MANAGER="$value" ;;
      path) APP_PATH="$value" ;;
      entrypoint) APP_ENTRYPOINT="$value" ;;
      compose_file) APP_COMPOSE_FILE="$value" ;;
      environment) APP_ENVIRONMENT="$value" ;;
    esac
  done <"$file"
}

app_config_validate_loaded() {
  validator_required "$APP_NAME" || return "$APPPILOT_ERR_CONFIG"
  validator_name "$APP_NAME" || return "$APPPILOT_ERR_CONFIG"
  validator_manager "$APP_MANAGER" || return "$APPPILOT_ERR_CONFIG"
  validator_path_safe "$APP_PATH" || return "$APPPILOT_ERR_CONFIG"
  [[ -d "$APP_PATH" ]] || return "$APPPILOT_ERR_CONFIG"
  if [[ "$APP_MANAGER" == "pm2" ]]; then
    validator_required "$APP_ENTRYPOINT" || return "$APPPILOT_ERR_CONFIG"
    [[ "$APP_ENTRYPOINT" != /* && "$APP_ENTRYPOINT" != *".."* ]] || return "$APPPILOT_ERR_CONFIG"
    [[ -f "$APP_PATH/$APP_ENTRYPOINT" ]] || return "$APPPILOT_ERR_CONFIG"
  else
    validator_required "$APP_COMPOSE_FILE" || return "$APPPILOT_ERR_CONFIG"
    [[ "$APP_COMPOSE_FILE" != /* && "$APP_COMPOSE_FILE" != *".."* ]] || return "$APPPILOT_ERR_CONFIG"
    [[ -f "$APP_PATH/$APP_COMPOSE_FILE" ]] || return "$APPPILOT_ERR_CONFIG"
  fi
}

app_config_to_json() {
  printf '{"name":%s,"manager":%s,"path":%s,"entrypoint":%s,"composeFile":%s,"environment":%s}' \
    "$(json_string "$APP_NAME")" "$(json_string "$APP_MANAGER")" "$(json_string "$APP_PATH")" \
    "$(json_string "$APP_ENTRYPOINT")" "$(json_string "$APP_COMPOSE_FILE")" "$(json_string "$APP_ENVIRONMENT")"
}
