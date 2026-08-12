#!/usr/bin/env bash

log_info() {
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  printf '%s\n' "$*"
}

log_warn() {
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  printf '%s!%s %s\n' "${APPPILOT_COLOR_YELLOW:-}" "${APPPILOT_COLOR_RESET:-}" "$*" >&2
}

log_error() {
  printf '%sError:%s %s\n' "${APPPILOT_COLOR_RED:-}" "${APPPILOT_COLOR_RESET:-}" "$*" >&2
}

log_check() {
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  printf '%sOK%s %s\n' "${APPPILOT_COLOR_GREEN:-}" "${APPPILOT_COLOR_RESET:-}" "$*"
}
