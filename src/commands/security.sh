#!/usr/bin/env bash

security_json_from_lines() {
  local first=1
  local severity id message
  printf '['
  while IFS='|' read -r severity id message; do
    [[ -n "$severity" ]] || continue
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    printf '{"severity":%s,"id":%s,"message":%s}' "$(json_string "$severity")" "$(json_string "$id")" "$(json_string "$message")"
  done
  printf ']'
}

cmd_security() {
  local subcommand="${1:-}"
  shift || true
  [[ "$subcommand" == "audit" ]] || { output_error "security supports only: audit" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ "$#" -eq 0 ]] || { output_error "security audit does not accept arguments" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }

  local tmp
  tmp="$(mktemp)"
  {
    ssh_audit_lines
    firewall_audit_lines
    docker_audit_lines
    permissions_audit_lines
  } >"$tmp"

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"findings\":$(security_json_from_lines <"$tmp")}"
    rm -f "$tmp"
    return "$APPPILOT_OK"
  else
    [[ "${APPPILOT_QUIET:-0}" == "1" ]] || { ui_title "AppPilot Security Audit"; printf '\n'; }
    local severity id message warnings=0
    while IFS='|' read -r severity id message; do
      case "$severity" in
        ok) ui_status_line ok "$message" ;;
        warning) warnings=$((warnings + 1)); ui_status_line warning "$message" ;;
        *) ui_status_line info "$message" ;;
      esac
      : "$id"
    done <"$tmp"
    [[ "${APPPILOT_QUIET:-0}" == "1" ]] || printf '\n%s warning(s) found.\n' "$warnings"
  fi
  rm -f "$tmp"
}
