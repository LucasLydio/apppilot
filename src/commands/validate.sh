#!/usr/bin/env bash

validate_json_checks() {
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

validate_collect() {
  config_exists && printf 'ok|config|AppPilot configuration exists\n' || printf 'error|config|AppPilot has not been initialized\n'
  [[ -d "$APPPILOT_APPS_DIR" ]] && printf 'ok|apps_dir|Application registry directory exists\n' || printf 'error|apps_dir|Application registry directory is missing\n'
  [[ -d "$APPPILOT_STATE_HOME" && -w "$APPPILOT_STATE_HOME" ]] && printf 'ok|state_writable|State directory is writable\n' || printf 'error|state_writable|State directory is not writable\n'
  [[ -d "$APPPILOT_LOCKS_DIR" && -w "$APPPILOT_LOCKS_DIR" ]] && printf 'ok|locks_writable|Lock directory is writable\n' || printf 'error|locks_writable|Lock directory is not writable\n'

  local name found=0
  while IFS= read -r name; do
    found=1
    if registry_load "$name" >/dev/null 2>&1; then
      printf 'ok|app_config|Application config valid: %s\n' "$name"
    else
      printf 'error|app_config|Application config invalid: %s\n' "$name"
    fi
  done < <(registry_names)
  [[ "$found" -eq 1 ]] || printf 'ok|registry_empty|No registered applications\n'
}

cmd_validate() {
  [[ "$#" -eq 0 ]] || { output_error "validate does not accept arguments" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  local tmp status id message errors=0 warnings=0
  tmp="$(mktemp)"
  validate_collect >"$tmp"

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"checks\":$(validate_json_checks <"$tmp")}"
    rm -f "$tmp"
    return "$APPPILOT_OK"
  fi

  [[ "${APPPILOT_QUIET:-0}" == "1" ]] || { ui_title "AppPilot Validate"; printf '\n'; }
  while IFS='|' read -r status id message; do
    case "$status" in
      ok) ui_status_line ok "$message" ;;
      warning) warnings=$((warnings + 1)); ui_status_line warning "$message" ;;
      error) errors=$((errors + 1)); ui_status_line error "$message" ;;
    esac
    : "$id"
  done <"$tmp"
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] || printf '\n%s warning(s), %s error(s) found.\n' "$warnings" "$errors"
  rm -f "$tmp"
  [[ "$errors" -eq 0 ]] || return "$APPPILOT_ERR_CONFIG"
}
