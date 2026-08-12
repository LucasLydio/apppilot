#!/usr/bin/env bash

operation_mutate() {
  local operation="$1"
  local app="${2:-}"
  local extra="${3:-}"
  [[ -n "$app" ]] || { output_error "$operation requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ -z "$extra" ]] || { output_error "$operation accepts only one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || { local code="$?"; output_error "Application not found or invalid: $app" "$code"; return "$code"; }

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"actions\":[\"$operation $(json_escape "$app")\"],\"manager\":$(json_string "$APP_MANAGER")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would $operation: $app"
      log_info "Manager: $APP_MANAGER"
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "$operation" "$app" || return "$?"
  local tmp code
  tmp="$(mktemp)"
  if adapter_"$operation" >"$tmp" 2>&1; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"manager\":$(json_string "$APP_MANAGER"),\"operation\":$(json_string "$operation")}"
    else
      log_check "$operation completed for $APP_NAME"
      [[ "${APPPILOT_QUIET:-0}" == "1" ]] || cat "$tmp"
    fi
    rm -f "$tmp"
    return "$APPPILOT_OK"
  fi
  code="$?"
  local message
  message="$(tr '\n' ' ' <"$tmp")"
  rm -f "$tmp"
  [[ -n "$message" ]] || message="$operation failed for $app"
  output_error "$message" "$code"
  return "$code"
}

cmd_start() { operation_mutate "start" "${1:-}" "${2:-}"; }
cmd_stop() { operation_mutate "stop" "${1:-}" "${2:-}"; }
cmd_restart() { operation_mutate "restart" "${1:-}" "${2:-}"; }

cmd_status() {
  local app="${1:-}"
  local extra="${2:-}"
  [[ -n "$app" ]] || { output_error "status requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ -z "$extra" ]] || { output_error "status accepts only one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || { local code="$?"; output_error "Application not found or invalid: $app" "$code"; return "$code"; }
  local tmp code status
  tmp="$(mktemp)"
  if adapter_status >"$tmp" 2>&1; then
    status="$(cat "$tmp")"
    rm -f "$tmp"
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"manager\":$(json_string "$APP_MANAGER"),\"status\":$(json_string "$status")}"
    else
      printf '%s\n' "$status"
    fi
    return "$APPPILOT_OK"
  fi
  code="$?"
  status="$(tr '\n' ' ' <"$tmp")"
  rm -f "$tmp"
  output_error "${status:-status failed for $app}" "$code"
  return "$code"
}

cmd_logs() {
  local app="${1:-}"
  shift || true
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --lines) APPPILOT_LOG_LINES="${2:-80}"; shift 2 ;;
      *) output_error "Unknown logs argument: $1" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
    esac
  done
  [[ -n "$app" ]] || { output_error "logs requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || { local code="$?"; output_error "Application not found or invalid: $app" "$code"; return "$code"; }
  local tmp code logs
  tmp="$(mktemp)"
  if adapter_logs >"$tmp" 2>&1; then
    logs="$(cat "$tmp")"
    rm -f "$tmp"
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"manager\":$(json_string "$APP_MANAGER"),\"logs\":$(json_string "$logs")}"
    else
      printf '%s\n' "$logs"
    fi
    return "$APPPILOT_OK"
  fi
  code="$?"
  logs="$(tr '\n' ' ' <"$tmp")"
  rm -f "$tmp"
  output_error "${logs:-logs failed for $app}" "$code"
  return "$code"
}
