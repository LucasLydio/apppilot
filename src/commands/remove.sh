#!/usr/bin/env bash

cmd_remove() {
  local name="" yes=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --yes|-y) yes=1; shift ;;
      *) if [[ -z "$name" ]]; then name="$1"; shift; else output_error "Unknown remove argument: $1" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done
  [[ -n "$name" ]] || { output_error "remove requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$name" >/dev/null 2>&1 || { output_error "Application not found: $name" "$APPPILOT_ERR_APP_NOT_FOUND"; return "$APPPILOT_ERR_APP_NOT_FOUND"; }

  if [[ "${APPPILOT_NON_INTERACTIVE:-0}" == "1" && "$yes" -ne 1 && "${APPPILOT_DRY_RUN:-0}" != "1" ]]; then
    output_error "remove requires --yes in non-interactive mode" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"
  fi

  if [[ "${APPPILOT_NON_INTERACTIVE:-0}" != "1" && "$yes" -ne 1 && -t 0 && "${APPPILOT_DRY_RUN:-0}" != "1" ]]; then
    local answer
    read -r -p "Remove $name from AppPilot? [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || return "$APPPILOT_OK"
  fi

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"actions\":[\"remove application $(json_escape "$name")\"]}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would remove application: $name"
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "remove" "$name" || return "$?"
  registry_remove "$name" || { local code="$?"; output_error "Could not remove application: $name" "$code"; return "$code"; }
  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"removed\":$(json_string "$name")}"
  else
    log_check "Removed $name"
  fi
}
