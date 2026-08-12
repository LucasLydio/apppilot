#!/usr/bin/env bash

doctor_has_manager_apps() {
  local manager="$1"
  local name
  while IFS= read -r name; do
    registry_load "$name" >/dev/null 2>&1 || continue
    [[ "$APP_MANAGER" == "$manager" ]] && return 0
  done < <(registry_names)
  return 1
}

doctor_json_checks() {
  local first=1
  local status id message
  printf '['
  while IFS='|' read -r status id message; do
    [[ -n "$status" ]] || continue
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    printf '{"status":%s,"id":%s,"message":%s}' "$(json_string "$status")" "$(json_string "$id")" "$(json_string "$message")"
  done
  printf ']'
}

doctor_collect() {
  host_detect
  [[ "$HOST_IS_LINUX" == "true" ]] && printf 'ok|linux|Linux detected\n' || printf 'error|linux|Linux not detected\n'
  host_supported_distro && printf 'ok|distro|Supported distro: %s\n' "$HOST_DISTRO_NAME" || printf 'warning|distro|Unsupported or untested distro: %s\n' "$HOST_DISTRO_NAME"
  printf 'ok|architecture|Architecture: %s\n' "$HOST_ARCH"
  printf 'ok|bash|Bash: %s\n' "$HOST_BASH_VERSION"
  printf 'ok|cpu|CPU count: %s\n' "$(resource_cpu_count)"
  printf 'ok|memory|Memory: %s\n' "$(resource_memory_summary)"
  printf 'ok|disk|Disk: %s\n' "$(resource_disk_summary)"
  printf 'ok|uptime|Uptime: %s\n' "$(resource_uptime_summary)"

  config_exists && printf 'ok|config|AppPilot configuration exists\n' || printf 'warning|config|AppPilot has not been initialized\n'
  [[ -d "$APPPILOT_STATE_HOME" && -w "$APPPILOT_STATE_HOME" ]] && printf 'ok|state_writable|State directory writable\n' || printf 'warning|state_writable|State directory is not writable\n'
  [[ -d "$APPPILOT_LOCKS_DIR" && -w "$APPPILOT_LOCKS_DIR" ]] && printf 'ok|locks_writable|Lock directory writable\n' || printf 'warning|locks_writable|Lock directory is not writable\n'
  command -v jq >/dev/null 2>&1 && printf 'ok|jq|jq installed\n' || printf 'warning|jq|jq not installed\n'

  if doctor_has_manager_apps "pm2"; then
    command -v pm2 >/dev/null 2>&1 && printf 'ok|pm2|PM2 installed\n' || printf 'error|pm2|PM2 required by registered apps but missing\n'
  fi
  if doctor_has_manager_apps "compose"; then
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
      printf 'ok|docker_compose|Docker Compose available\n'
    else
      printf 'error|docker_compose|Docker Compose required by registered apps but missing\n'
    fi
  fi

  local name
  while IFS= read -r name; do
    if registry_load "$name" >/dev/null 2>&1; then
      printf 'ok|app_config|Application config valid: %s\n' "$name"
      if adapter_validate >/dev/null 2>&1; then
        printf 'ok|app_dependency|Application manager available: %s\n' "$name"
        if adapter_status >/dev/null 2>&1; then
          printf 'ok|app_status|Application status readable: %s\n' "$name"
        else
          printf 'warning|app_status|Application status unknown or stopped: %s\n' "$name"
        fi
      else
        printf 'warning|app_dependency|Application manager unavailable: %s\n' "$name"
      fi
    else
      printf 'error|app_config|Application config invalid: %s\n' "$name"
    fi
  done < <(registry_names)
}

cmd_doctor() {
  [[ "$#" -eq 0 ]] || { output_error "doctor does not accept arguments" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  local tmp
  tmp="$(mktemp)"
  doctor_collect >"$tmp"

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"host\":$(host_json),\"resources\":$(resources_json),\"ports\":$(ports_json_array),\"checks\":$(doctor_json_checks <"$tmp")}"
    rm -f "$tmp"
    return "$APPPILOT_OK"
  else
    [[ "${APPPILOT_QUIET:-0}" == "1" ]] || printf '%sAppPilot Doctor%s\n\n' "${APPPILOT_COLOR_BOLD:-}" "${APPPILOT_COLOR_RESET:-}"
    local status id message warnings=0 errors=0
    while IFS='|' read -r status id message; do
      case "$status" in
        ok) log_check "$message" ;;
        warning) warnings=$((warnings + 1)); log_warn "$message" ;;
        error) errors=$((errors + 1)); log_error "$message" ;;
      esac
      : "$id"
    done <"$tmp"
    [[ "${APPPILOT_QUIET:-0}" == "1" ]] || printf '\n%s warning(s), %s error(s) found.\n' "$warnings" "$errors"
  fi
  rm -f "$tmp"
}
