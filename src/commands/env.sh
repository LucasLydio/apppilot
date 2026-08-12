#!/usr/bin/env bash

cmd_env_init() {
  local app=""
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dry-run) APPPILOT_DRY_RUN=1; export APPPILOT_DRY_RUN; shift ;;
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "env init accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done
  [[ -n "$app" ]] || { output_error "env init requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }

  registry_load "$app" || {
    local code="$?"
    output_error "Application not found or invalid: $app" "$code"
    return "$code"
  }

  if [[ -e "$APP_PATH/.env" ]]; then
    output_error ".env already exists for '$APP_NAME'" "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  fi

  if [[ ! -f "$APP_PATH/.env.example" || -L "$APP_PATH/.env.example" ]]; then
    output_error ".env.example not found for '$APP_NAME'" "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  fi

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"actions\":[\"create .env from .env.example\"],\"app\":$(json_string "$APP_NAME"),\"path\":$(json_string "$APP_PATH/.env")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would create .env from .env.example for: $APP_NAME"
      log_info "Path: $APP_PATH/.env"
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "env-init" "$APP_NAME" || return "$?"
  env_create_from_example "$APP_PATH" || {
    local code="$?"
    output_error "Could not create .env from .env.example for '$APP_NAME'" "$code"
    return "$code"
  }

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$APP_NAME"),\"path\":$(json_string "$APP_PATH/.env"),\"created\":true}"
  else
    log_check "Created .env from .env.example for $APP_NAME"
    log_info "Edit it before restarting the app:"
    log_info "  nano $APP_PATH/.env"
  fi
}

cmd_env() {
  local subcommand="${1:-}"
  shift || true
  case "$subcommand" in
    init) cmd_env_init "$@" ;;
    *) output_error "Unknown env command: ${subcommand:-}" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
  esac
}
