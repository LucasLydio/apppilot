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
  if [[ "${APPPILOT_QUIET:-0}" != "1" ]]; then
    printf '%sAppPilot Applications%s\n\n' "${APPPILOT_COLOR_BOLD:-}" "${APPPILOT_COLOR_RESET:-}"
  fi
  local found=0
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    registry_load "$name" >/dev/null 2>&1 || continue
    found=1
    printf '%-24s %-8s %s\n' "$APP_NAME" "$APP_MANAGER" "$APP_PATH"
  done < <(registry_names)
  [[ "$found" -eq 1 || "${APPPILOT_QUIET:-0}" == "1" ]] || printf 'No applications registered.\n'
}
