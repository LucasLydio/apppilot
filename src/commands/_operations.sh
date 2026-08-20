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

status_detail() {
  local file="$1"
  local key="$2"
  awk -F '\t' -v wanted="$key" '$1 == wanted { print substr($0, index($0, $2)); exit }' "$file"
}

status_color() {
  local status="$1"
  case "$status" in
    online|running|up) printf '%s%s%s' "${APPPILOT_COLOR_GREEN:-}" "$status" "${APPPILOT_COLOR_RESET:-}" ;;
    stopped|errored|error|offline) printf '%s%s%s' "${APPPILOT_COLOR_RED:-}" "$status" "${APPPILOT_COLOR_RESET:-}" ;;
    *) printf '%s%s%s' "${APPPILOT_COLOR_YELLOW:-}" "$status" "${APPPILOT_COLOR_RESET:-}" ;;
  esac
}

status_repeat() {
  local char="$1"
  local count="$2"
  local value
  printf -v value '%*s' "$count" ''
  printf '%s' "${value// /$char}"
}

status_fit() {
  local value="${1:-}"
  local width="$2"
  if [[ "${#value}" -gt "$width" ]]; then
    printf '%s' "${value:0:$((width - 1))}~"
  else
    printf "%-${width}s" "$value"
  fi
}

status_table_border() {
  local kind="$1"
  local left sep right width index
  local -a widths=(22 8 10 8 7 8 8 8 8 18)
  case "$kind" in
    top) left="┌"; sep="┬"; right="┐" ;;
    mid) left="├"; sep="┼"; right="┤" ;;
    *) left="└"; sep="┴"; right="┘" ;;
  esac

  printf '  %s' "$left"
  for index in "${!widths[@]}"; do
    width="${widths[$index]}"
    status_repeat "─" "$((width + 2))"
    if [[ "$index" -lt "$((${#widths[@]} - 1))" ]]; then
      printf '%s' "$sep"
    else
      printf '%s\n' "$right"
    fi
  done
}

status_table_row() {
  local name="$1"
  local manager="$2"
  local status="$3"
  local pid="$4"
  local cpu="$5"
  local memory="$6"
  local restarts="$7"
  local uptime="$8"
  local services="$9"
  local target="${10}"
  local status_cell

  status_cell="$(status_fit "$status" 10)"
  printf '  │ %s │ %s │ ' "$(status_fit "$name" 22)" "$(status_fit "$manager" 8)"
  case "$status" in
    Status) printf '%s' "$status_cell" ;;
    online|running|up) printf '%s%s%s' "${APPPILOT_COLOR_GREEN:-}" "$status_cell" "${APPPILOT_COLOR_RESET:-}" ;;
    stopped|errored|error|offline) printf '%s%s%s' "${APPPILOT_COLOR_RED:-}" "$status_cell" "${APPPILOT_COLOR_RESET:-}" ;;
    *) printf '%s%s%s' "${APPPILOT_COLOR_YELLOW:-}" "$status_cell" "${APPPILOT_COLOR_RESET:-}" ;;
  esac
  printf ' │ %s │ %s │ %s │ %s │ %s │ %s │ %s │\n' \
    "$(status_fit "$pid" 8)" \
    "$(status_fit "$cpu" 7)" \
    "$(status_fit "$memory" 8)" \
    "$(status_fit "$restarts" 8)" \
    "$(status_fit "$uptime" 8)" \
    "$(status_fit "$services" 8)" \
    "$(status_fit "$target" 18)"
}

status_memory() {
  local bytes="${1:-0}"
  [[ "$bytes" =~ ^[0-9]+$ ]] || { printf '%s' "-"; return 0; }
  if [[ "$bytes" -ge 1073741824 ]]; then
    awk -v value="$bytes" 'BEGIN { printf "%.1fG", value / 1073741824 }'
  elif [[ "$bytes" -ge 1048576 ]]; then
    awk -v value="$bytes" 'BEGIN { printf "%.1fM", value / 1048576 }'
  elif [[ "$bytes" -gt 0 ]]; then
    awk -v value="$bytes" 'BEGIN { printf "%.1fK", value / 1024 }'
  else
    printf '%s' "-"
  fi
}

status_uptime() {
  local seconds="${1:-0}"
  [[ "$seconds" =~ ^[0-9]+$ ]] || { printf '%s' "-"; return 0; }
  [[ "$seconds" -gt 0 ]] || { printf '%s' "-"; return 0; }
  local days hours minutes
  days=$((seconds / 86400))
  hours=$(((seconds % 86400) / 3600))
  minutes=$(((seconds % 3600) / 60))
  if [[ "$days" -gt 0 ]]; then
    printf '%sd %sh' "$days" "$hours"
  elif [[ "$hours" -gt 0 ]]; then
    printf '%sh %sm' "$hours" "$minutes"
  else
    printf '%sm' "$minutes"
  fi
}

status_print_table() {
  local details_file="$1"
  local status pid cpu memory restarts uptime target runtime_name services
  status="$(status_detail "$details_file" status)"
  runtime_name="$(status_detail "$details_file" runtimeName)"
  pid="$(status_detail "$details_file" pid)"
  cpu="$(status_detail "$details_file" cpu)"
  memory="$(status_memory "$(status_detail "$details_file" memoryBytes)")"
  restarts="$(status_detail "$details_file" restarts)"
  uptime="$(status_uptime "$(status_detail "$details_file" uptimeSeconds)")"
  services="$(status_detail "$details_file" services)"
  [[ -n "$status" ]] || status="unknown"
  [[ -n "$runtime_name" ]] || runtime_name="-"
  [[ -n "$pid" ]] || pid="-"
  [[ -n "$cpu" ]] || cpu="-"
  [[ -n "$restarts" ]] || restarts="-"
  [[ -n "$services" ]] || services="-"
  case "$APP_MANAGER" in
    compose) target="$APP_COMPOSE_FILE" ;;
    static) target="$APP_BUILD_DIR" ;;
    *) target="$APP_ENTRYPOINT" ;;
  esac

  ui_title "AppPilot Status"
  printf '\n'
  status_table_border top
  status_table_row "Name" "Manager" "Status" "PID" "CPU" "Memory" "Restarts" "Uptime" "Services" "Target"
  status_table_border mid
  status_table_row "$APP_NAME" "$APP_MANAGER" "$status" "$pid" "$cpu" "$memory" "$restarts" "$uptime" "$services" "$target"
  status_table_border bottom
  if [[ "$runtime_name" != "-" && "$runtime_name" != "$APP_NAME" ]]; then
    printf '\n'
    ui_kv "Runtime name" "$runtime_name"
  fi
}

status_print_full() {
  local details_file="$1"
  local status
  status="$(status_detail "$details_file" status)"
  [[ -n "$status" ]] || status="unknown"
  ui_title "AppPilot Status"
  printf '\n'
  ui_kv "Name" "$APP_NAME"
  ui_kv "Manager" "$APP_MANAGER"
  ui_kv "Status" "$(status_color "$status")"
  ui_kv "Path" "$APP_PATH"
  ui_kv "Environment" "$APP_ENVIRONMENT"
  if [[ "$APP_MANAGER" == "pm2" ]]; then
    ui_kv "Runtime name" "$(status_detail "$details_file" runtimeName)"
    ui_kv "PM2 id" "$(status_detail "$details_file" pmId)"
    ui_kv "PID" "$(status_detail "$details_file" pid)"
    ui_kv "CPU" "$(status_detail "$details_file" cpu)"
    ui_kv "Memory" "$(status_memory "$(status_detail "$details_file" memoryBytes)")"
    ui_kv "Restarts" "$(status_detail "$details_file" restarts)"
    ui_kv "Uptime" "$(status_uptime "$(status_detail "$details_file" uptimeSeconds)")"
    ui_kv "User" "$(status_detail "$details_file" user)"
    ui_kv "Interpreter" "$(status_detail "$details_file" interpreter)"
    ui_kv "Exec mode" "$(status_detail "$details_file" execMode)"
    ui_kv "Entrypoint" "$APP_ENTRYPOINT"
    ui_kv "Script path" "$(status_detail "$details_file" scriptPath)"
  elif [[ "$APP_MANAGER" == "compose" ]]; then
    ui_kv "Runtime name" "$(status_detail "$details_file" runtimeName)"
    ui_kv "Services" "$(status_detail "$details_file" services)"
    ui_kv "Compose file" "$APP_COMPOSE_FILE"
    ui_kv "Project" "$(status_detail "$details_file" project)"
  else
    ui_kv "Runtime name" "$(status_detail "$details_file" runtimeName)"
    ui_kv "Build directory" "$APP_BUILD_DIR"
  fi
  ui_kv "Config file" "$(app_config_file_for "$APP_NAME")"
}

status_details_json() {
  local details_file="$1"
  printf '{"status":%s,"runtimeName":%s,"pid":%s,"cpu":%s,"memoryBytes":%s,"restarts":%s,"uptimeSeconds":%s,"services":%s,"path":%s,"entrypoint":%s,"composeFile":%s,"buildDir":%s,"environment":%s}' \
    "$(json_string "$(status_detail "$details_file" status)")" \
    "$(json_string "$(status_detail "$details_file" runtimeName)")" \
    "$(json_string "$(status_detail "$details_file" pid)")" \
    "$(json_string "$(status_detail "$details_file" cpu)")" \
    "$(json_string "$(status_detail "$details_file" memoryBytes)")" \
    "$(json_string "$(status_detail "$details_file" restarts)")" \
    "$(json_string "$(status_detail "$details_file" uptimeSeconds)")" \
    "$(json_string "$(status_detail "$details_file" services)")" \
    "$(json_string "$APP_PATH")" \
    "$(json_string "$APP_ENTRYPOINT")" \
    "$(json_string "$APP_COMPOSE_FILE")" \
    "$(json_string "$APP_BUILD_DIR")" \
    "$(json_string "$APP_ENVIRONMENT")"
}

cmd_status() {
  local app="" full=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --full) full=1; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "status accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done
  [[ -n "$app" ]] || { output_error "status requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || { local code="$?"; output_error "Application not found or invalid: $app" "$code"; return "$code"; }
  local tmp code status_json
  tmp="$(mktemp)"
  if adapter_status_details >"$tmp" 2>&1; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      status_json="$(status_details_json "$tmp")"
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"manager\":$(json_string "$APP_MANAGER"),\"full\":$(json_bool "$full"),\"status\":$status_json}"
    else
      if [[ "$full" -eq 1 ]]; then
        status_print_full "$tmp"
      else
        status_print_table "$tmp"
      fi
    fi
    rm -f "$tmp"
    return "$APPPILOT_OK"
  fi
  code="$?"
  local status
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
      --lines) APPPILOT_LOG_LINES="${2:-80}"; export APPPILOT_LOG_LINES; shift 2 ;;
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
