#!/usr/bin/env bash

cmd_add() {
  local name="" manager="" path="" entrypoint="" compose_file="" environment="production"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --name) name="${2:-}"; shift 2 ;;
      --manager) manager="${2:-}"; shift 2 ;;
      --path) path="${2:-}"; shift 2 ;;
      --entrypoint) entrypoint="${2:-}"; shift 2 ;;
      --compose-file) compose_file="${2:-}"; shift 2 ;;
      --environment) environment="${2:-production}"; shift 2 ;;
      *) output_error "Unknown add argument: $1" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
    esac
  done

  if [[ "${APPPILOT_NON_INTERACTIVE:-0}" != "1" && -t 0 ]]; then
    [[ -n "$name" ]] || read -r -p "Name: " name
    [[ -n "$manager" ]] || read -r -p "Manager (pm2/compose): " manager
    [[ -n "$path" ]] || read -r -p "Path: " path
    if [[ "$manager" == "pm2" ]]; then
      [[ -n "$entrypoint" ]] || read -r -p "Entrypoint: " entrypoint
    elif [[ "$manager" == "compose" ]]; then
      [[ -n "$compose_file" ]] || read -r -p "Compose file: " compose_file
    fi
  fi

  [[ -n "$name" && -n "$manager" && -n "$path" ]] || {
    output_error "add requires --name, --manager, and --path" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"
  }

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    registry_validate_new "$name" "$manager" "$path" "$entrypoint" "$compose_file" || {
      local code="$?"
      output_error "Could not register application '$name'" "$code"; return "$code"
    }
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"actions\":[\"register application $(json_escape "$name")\"]}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would register application: $name"
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "add" "$name" || return "$?"
  registry_add "$name" "$manager" "$path" "$entrypoint" "$compose_file" "$environment" || {
    local code="$?"
    output_error "Could not register application '$name'" "$code"; return "$code"
  }

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$name"),\"manager\":$(json_string "$manager")}"
  else
    log_check "Registered $name ($manager)"
  fi
}
