#!/usr/bin/env bash

output_error() {
  local message="$1"
  local code="${2:-$APPPILOT_ERR_GENERIC}"
  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    printf '{"success":false,"data":{},"warnings":[],"errors":[{"code":%s,"message":%s}]}\n' \
      "$code" "$(json_string "$message")"
  else
    log_error "$message"
  fi
  return 0
}

output_success_json() {
  local data="${1:-{}}"
  local warnings="${2:-[]}"
  local dry_run="${3:-false}"
  printf '{"success":true,"dryRun":%s,"data":%s,"warnings":%s,"errors":[]}\n' \
    "$(json_bool "$dry_run")" "$data" "$warnings"
}

output_dry_run_header() {
  [[ "${APPPILOT_JSON:-0}" == "1" || "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  printf '%sDRY RUN%s\n\n' "${APPPILOT_COLOR_BOLD:-}" "${APPPILOT_COLOR_RESET:-}"
}
