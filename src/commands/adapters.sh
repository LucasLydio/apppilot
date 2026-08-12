#!/usr/bin/env bash

adapter_status_pm2() {
  command -v pm2 >/dev/null 2>&1 && printf 'installed' || printf 'missing'
}

adapter_status_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    printf 'missing'
  elif ! docker compose version >/dev/null 2>&1; then
    printf 'partial'
  else
    printf 'installed'
  fi
}

adapters_json() {
  local pm2_status compose_status
  pm2_status="$(adapter_status_pm2)"
  compose_status="$(adapter_status_compose)"
  printf '[{"name":"pm2","type":"process-manager","builtIn":true,"status":%s,"requiredCommands":["pm2"]},{"name":"compose","type":"container-orchestrator","builtIn":true,"status":%s,"requiredCommands":["docker","docker compose"]}]' \
    "$(json_string "$pm2_status")" "$(json_string "$compose_status")"
}

cmd_adapters() {
  local subcommand="${1:-list}"
  shift || true
  [[ "$subcommand" == "list" ]] || { output_error "adapters supports only: list" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ "$#" -eq 0 ]] || { output_error "adapters list does not accept arguments" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"adapters\":$(adapters_json)}"
    return "$APPPILOT_OK"
  fi

  [[ "${APPPILOT_QUIET:-0}" == "1" ]] || printf '%sAppPilot Adapters%s\n\n' "${APPPILOT_COLOR_BOLD:-}" "${APPPILOT_COLOR_RESET:-}"
  printf '%-12s %-24s %-10s %s\n' "Name" "Type" "Status" "Required commands"
  printf '%-12s %-24s %-10s %s\n' "pm2" "process-manager" "$(adapter_status_pm2)" "pm2"
  printf '%-12s %-24s %-10s %s\n' "compose" "container-orchestrator" "$(adapter_status_compose)" "docker, docker compose"
}
