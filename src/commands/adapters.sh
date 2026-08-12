#!/usr/bin/env bash

cmd_adapters_install() {
  local target="${1:-missing}" yes=0
  local targets=()
  local item joined

  [[ "${1:-}" != "" ]] && shift
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --yes|-y) yes=1; shift ;;
      *) output_error "Unknown adapters install argument: $1" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
    esac
  done

  case "$target" in
    missing) while IFS= read -r item; do [[ -n "$item" ]] && targets+=("$item"); done < <(adapters_missing_targets) ;;
    all) targets=("pm2" "compose") ;;
    pm2|compose) targets=("$target") ;;
    *) output_error "Unknown adapter: $target" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
  esac

  if [[ "${#targets[@]}" -eq 0 ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json '{"actions":[],"message":"All adapter dependencies are installed"}'
    else
      log_check "All adapter dependencies are installed"
    fi
    return "$APPPILOT_OK"
  fi

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      printf -v joined '%s\n' "${targets[@]}"
      output_success_json "{\"actions\":$(adapters_install_json_plan <<<"$joined")}" "[]" "true"
    else
      output_dry_run_header
      for item in "${targets[@]}"; do
        printf 'Would install adapter dependencies for: %s\n' "$item"
        adapter_install_plan "$item" | sed 's/^/- /'
      done
      printf '\nNo changes were made.\n'
    fi
    return "$APPPILOT_OK"
  fi

  if [[ "${APPPILOT_NON_INTERACTIVE:-0}" == "1" && "$yes" != "1" ]]; then
    output_error "adapters install requires --yes in non-interactive mode" "$APPPILOT_ERR_ARGS"
    return "$APPPILOT_ERR_ARGS"
  fi

  adapter_require_supported_apt_host || {
    local code="$?"
    output_error "Adapter installation currently supports Ubuntu/Debian systems with apt only" "$code"
    return "$code"
  }

  lock_acquire "adapters-install" "$target" || return "$?"
  for item in "${targets[@]}"; do
    adapter_confirm_install "$item" "$yes" || return "$?"
    adapter_install_one "$item" || {
      local code="$?"
      output_error "Could not install adapter dependencies for $item" "$code"
      return "$code"
    }
  done

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"installed\":$(adapters_json)}"
  else
    log_check "Adapter dependency installation completed"
    cmd_adapters list
  fi
}

cmd_adapters_updates() {
  [[ "$#" -eq 0 ]] || { output_error "adapters updates does not accept arguments" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"pm2\":$(json_string "$(adapter_pm2_update_status)"),\"compose\":$(json_string "$(adapter_compose_update_status)")}"
    return "$APPPILOT_OK"
  fi
  [[ "${APPPILOT_QUIET:-0}" == "1" ]] || printf '%sAppPilot Adapter Updates%s\n\n' "${APPPILOT_COLOR_BOLD:-}" "${APPPILOT_COLOR_RESET:-}"
  printf '%-12s %s\n' "pm2" "$(adapter_pm2_update_status)"
  printf '%-12s %s\n' "compose" "$(adapter_compose_update_status)"
}

cmd_adapters() {
  local subcommand="${1:-list}"
  shift || true
  case "$subcommand" in
    install) cmd_adapters_install "$@"; return "$?" ;;
    updates) cmd_adapters_updates "$@"; return "$?" ;;
    list) ;;
    *) output_error "adapters supports only: list, install, updates" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
  esac
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
