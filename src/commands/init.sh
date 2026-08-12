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
    [[ "${APPPILOT_QUIET:-0}" == "1" ]] && return "$APPPILOT_OK"
    ui_welcome
    ui_section "Initialized"
    ui_status_line ok "Config" "$APPPILOT_CONFIG_HOME"
    ui_status_line ok "State" "$APPPILOT_STATE_HOME"
    ui_section "Next Steps"
    printf '  1. apppilot adapters list\n'
    printf '  2. apppilot adapters install pm2 --dry-run\n'
    printf '  3. apppilot overview\n'
    printf '  4. apppilot doctor\n'
    ui_section "Contribute"
    ui_kv "Repository" "https://github.com/LucasLydio/apppilot"
    ui_kv "Issues" "https://github.com/LucasLydio/apppilot/issues"
    ui_kv "Feedback" "Open an issue with your VPS, app manager, and use case"
  fi
}
