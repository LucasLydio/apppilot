#!/usr/bin/env bash

health_runtime_status() {
  local tmp status code
  tmp="$(mktemp)"
  if adapter_status_details >"$tmp" 2>/dev/null; then
    status="$(awk -F '\t' '$1 == "status" {print $2; exit}' "$tmp")"
    rm -f "$tmp"
    [[ -n "$status" ]] || status="unknown"
    printf '%s' "$status"
    return "$APPPILOT_OK"
  fi
  code="$?"
  rm -f "$tmp"
  return "$code"
}

health_json_actions() {
  local first=1 action
  printf '['
  for action in "$@"; do
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    json_string "$action"
  done
  printf ']'
}

health_url_check() {
  local url="$1"
  local timeout="$2"
  command -v curl >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
  curl -fsS --max-time "$timeout" "$url" >/dev/null
}

cmd_health() {
  local app="" url="" timeout=5 runtime_status=""
  local -a actions=()

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --url)
        [[ -n "${2:-}" ]] || { output_error "--url requires an HTTP URL" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        url="$2"
        shift 2
        ;;
      --timeout)
        [[ -n "${2:-}" ]] || { output_error "--timeout requires seconds" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        timeout="$2"
        shift 2
        ;;
      --dry-run) APPPILOT_DRY_RUN=1; export APPPILOT_DRY_RUN; shift ;;
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "health accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done

  [[ -n "$app" ]] || { output_error "health requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ "$timeout" =~ ^[0-9]+$ && "$timeout" -gt 0 ]] || {
    output_error "--timeout must be a positive integer" "$APPPILOT_ERR_ARGS"
    return "$APPPILOT_ERR_ARGS"
  }
  registry_load "$app" || {
    local code="$?"
    output_error "Application not found or invalid: $app" "$code"
    return "$code"
  }

  actions+=("check runtime status for $APP_NAME")
  [[ -n "$url" ]] && actions+=("request $url with timeout ${timeout}s")

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"url\":$(json_string "$url"),\"actions\":$(health_json_actions "${actions[@]}")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would check health: $APP_NAME"
      local action
      for action in "${actions[@]}"; do
        log_info "- $action"
      done
      log_info ""
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  runtime_status="$(health_runtime_status)" || {
    local code="$?"
    output_error "Could not read runtime status for '$APP_NAME'" "$code"
    return "$code"
  }

  if [[ "$runtime_status" != "online" ]]; then
    output_error "Health check failed: runtime status is $runtime_status" "$APPPILOT_ERR_HEALTH"
    return "$APPPILOT_ERR_HEALTH"
  fi

  if [[ -n "$url" ]]; then
    health_url_check "$url" "$timeout" || {
      local code="$?"
      [[ "$code" -eq "$APPPILOT_ERR_MISSING_DEP" ]] && output_error "curl is required for URL health checks" "$code"
      [[ "$code" -eq "$APPPILOT_ERR_MISSING_DEP" ]] || output_error "Health check failed: URL did not respond successfully: $url" "$APPPILOT_ERR_HEALTH"
      [[ "$code" -eq "$APPPILOT_ERR_MISSING_DEP" ]] && return "$code"
      return "$APPPILOT_ERR_HEALTH"
    }
  fi

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$APP_NAME"),\"runtimeStatus\":$(json_string "$runtime_status"),\"url\":$(json_string "$url"),\"healthy\":true}"
  else
    ui_title "AppPilot Health"
    printf '\n'
    log_check "Runtime status: $runtime_status"
    [[ -n "$url" ]] && log_check "URL responded: $url"
  fi
  return "$APPPILOT_OK"
}
