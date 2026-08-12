#!/usr/bin/env bash

cmd_list() {
  if [[ "$#" -ne 0 ]]; then
    output_error "list does not accept arguments" "$APPPILOT_ERR_ARGS"
    return "$APPPILOT_ERR_ARGS"
  fi
  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"apps\":$(registry_json_array)}"
    return "$APPPILOT_OK"
  fi

  local name
  local row_prefix="  "
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] && row_prefix=""
  if [[ "${APPPILOT_QUIET:-0}" != "1" ]]; then
    ui_title "AppPilot Applications"
    printf '\n'
  fi
  local found=0
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] || printf '  %-24s %-10s %s\n' "Name" "Manager" "Path"
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] || printf '  %-24s %-10s %s\n' "------------------------" "----------" "----------------"
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    registry_load "$name" >/dev/null 2>&1 || continue
    found=1
    printf '%s%-24s %-10s %s\n' "$row_prefix" "$APP_NAME" "$APP_MANAGER" "$APP_PATH"
  done < <(registry_names)
  [[ "$found" -eq 1 || "${APPPILOT_QUIET:-0}" == "1" ]] || printf 'No applications registered.\n'
}
