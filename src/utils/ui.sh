#!/usr/bin/env bash

ui_line() {
  printf '%s\n' '------------------------------------------------------------'
}

ui_frame_line() {
  printf '%s\n' '+----------------------------------------------------------+'
}

ui_frame_text() {
  local text="${1:-}"
  printf '| %-56s |\n' "$text"
}

ui_frame_blank() {
  printf '| %-56s |\n' ''
}

ui_title() {
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  printf '%s\n' "${APPPILOT_COLOR_BOLD:-}$1${APPPILOT_COLOR_RESET:-}"
}

ui_banner() {
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  ui_line
  printf '%s\n' "${APPPILOT_COLOR_BOLD:-}AppPilot${APPPILOT_COLOR_RESET:-} ${APPPILOT_VERSION:-0.1.0}"
  printf '%s\n' 'DevOps control for Linux VPS applications'
  ui_line
}

ui_welcome() {
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  ui_frame_line
  ui_frame_text "   ___              ____  _ _       _"
  ui_frame_text "  / _ \\ _ __  _ __ |  _ \\(_) | ___ | |_"
  ui_frame_text " | |_| | '_ \\| '_ \\| |_) | | |/ _ \\| __|"
  ui_frame_text " |  _  | |_) | |_) |  __/| | | (_) | |_"
  ui_frame_text " |_| |_| .__/| .__/|_|   |_|_|\\___/ \\__|"
  ui_frame_text "       |_|   |_|"
  ui_frame_blank
  ui_frame_text "DevOps control for Linux VPS applications"
  ui_frame_text "Safe defaults. Adapter-based operations. JSON-ready."
  ui_frame_line
}

ui_section() {
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  printf '\n%s%s%s\n' "${APPPILOT_COLOR_BOLD:-}" "$1" "${APPPILOT_COLOR_RESET:-}"
}

ui_kv() {
  printf '  %-18s %s\n' "$1" "$2"
}

ui_status_line() {
  local status="$1"
  local label="$2"
  local detail="${3:-}"
  local marker="OK"
  local color="${APPPILOT_COLOR_GREEN:-}"
  case "$status" in
    warning|partial|missing) marker="!"; color="${APPPILOT_COLOR_YELLOW:-}" ;;
    error|failed) marker="X"; color="${APPPILOT_COLOR_RED:-}" ;;
    info|unknown) marker="-"; color="" ;;
  esac
  if [[ -n "$detail" ]]; then
    printf '  %s%s%s %-24s %s\n' "$color" "$marker" "${APPPILOT_COLOR_RESET:-}" "$label" "$detail"
  else
    printf '  %s%s%s %s\n' "$color" "$marker" "${APPPILOT_COLOR_RESET:-}" "$label"
  fi
}

ui_table_header() {
  printf '  %-14s %-24s %-12s %s\n' "$1" "$2" "$3" "$4"
  printf '  %-14s %-24s %-12s %s\n' '--------------' '------------------------' '------------' '----------------'
}
