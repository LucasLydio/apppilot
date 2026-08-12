#!/usr/bin/env bash

cmd_init() {
  if [[ "$#" -ne 0 ]]; then
    output_error "init does not accept arguments" "$APPPILOT_ERR_ARGS"
    return "$APPPILOT_ERR_ARGS"
  fi
  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    local actions=()
    local action
    while IFS= read -r action; do
      [[ -n "$action" ]] && actions+=("$action")
    done < <(config_init)
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      local first=1
      local json='['
      for action in "${actions[@]}"; do
        [[ "$first" -eq 0 ]] && json+=','
        first=0
        json+="$(json_string "$action")"
      done
      json+=']'
      output_success_json "{\"actions\":$json}" "[]" "true"
    else
      output_dry_run_header
      if [[ "${#actions[@]}" -eq 0 ]]; then
        log_info "No changes would be made."
      else
        local planned
        printf 'Would perform:\n'
        for planned in "${actions[@]}"; do
          printf '%s %s\n' '-' "$planned"
        done
        printf '\nNo changes were made.\n'
      fi
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "init" "global" || return "$?"
  config_init
  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"configHome\":$(json_string "$APPPILOT_CONFIG_HOME"),\"stateHome\":$(json_string "$APPPILOT_STATE_HOME")}"
  else
    log_check "AppPilot initialized"
    log_info "Config: $APPPILOT_CONFIG_HOME"
    log_info "State:  $APPPILOT_STATE_HOME"
  fi
}
