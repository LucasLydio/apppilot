#!/usr/bin/env bash

deploy_git_reset_hard() {
  local revision="$1"
  (cd "$APP_PATH" && git reset --hard "$revision")
}

deploy_latest_previous_revision() {
  local file
  file="$(deploy_history_file)"
  [[ -f "$file" ]] || return "$APPPILOT_ERR_CONFIG"
  awk -F '\t' 'NF >= 9 && $7 != "-" { previous=$7 } END { if (previous) print previous; else exit 1 }' "$file"
}

deploy_short_revision() {
  local revision="${1:-}"
  if [[ "$revision" == "-" || -z "$revision" ]]; then
    printf '%s' "-"
  else
    printf '%s' "${revision:0:12}"
  fi
}

deploy_history_json_array() {
  local file="$1"
  local first=1 timestamp result app manager remote branch before after stage
  printf '['
  while IFS=$'\t' read -r timestamp result app manager remote branch before after stage; do
    [[ -n "$timestamp" ]] || continue
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    printf '{"timestamp":%s,"result":%s,"app":%s,"manager":%s,"remote":%s,"branch":%s,"before":%s,"after":%s,"stage":%s}' \
      "$(json_string "$timestamp")" "$(json_string "$result")" "$(json_string "$app")" "$(json_string "$manager")" \
      "$(json_string "$remote")" "$(json_string "$branch")" "$(json_string "$before")" "$(json_string "$after")" "$(json_string "$stage")"
  done <"$file"
  printf ']'
}

deploy_print_history() {
  local file="$1"
  local timestamp result _app manager remote branch before after stage
  ui_title "Deploy History"
  printf '\n'
  printf '  %-20s %-9s %-8s %-10s %-12s %-12s %s\n' "Time (UTC)" "Result" "Manager" "Remote" "Before" "After" "Stage"
  printf '  %-20s %-9s %-8s %-10s %-12s %-12s %s\n' "--------------------" "---------" "--------" "----------" "------------" "------------" "----------------"
  while IFS=$'\t' read -r timestamp result _app manager remote branch before after stage; do
    [[ -n "$timestamp" ]] || continue
    printf '  %-20s %-9s %-8s %-10s %-12s %-12s %s\n' \
      "$timestamp" "$result" "$manager" "$remote/$branch" "$(deploy_short_revision "$before")" "$(deploy_short_revision "$after")" "$stage"
  done < <(tail -n 10 "$file")
}

cmd_deploy_history() {
  local app="" file
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "deploy history accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done

  [[ -n "$app" ]] || { output_error "deploy history requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || {
    local code="$?"
    output_error "Application not found or invalid: $app" "$code"
    return "$code"
  }

  file="$(deploy_history_file)"
  if [[ ! -f "$file" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"history\":[]}"
    else
      log_info "No deploy history for $APP_NAME"
    fi
    return "$APPPILOT_OK"
  fi

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$APP_NAME"),\"history\":$(deploy_history_json_array "$file")}"
  else
    deploy_print_history "$file"
  fi
}

cmd_deploy_rollback() {
  local app="" target="" allow_dirty=0
  local current_revision=""
  local -a actions=()
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --to)
        [[ -n "${2:-}" ]] || { output_error "--to requires a revision" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        target="$2"
        shift 2
        ;;
      --allow-dirty) allow_dirty=1; shift ;;
      --dry-run) APPPILOT_DRY_RUN=1; export APPPILOT_DRY_RUN; shift ;;
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "deploy rollback accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done

  [[ -n "$app" ]] || { output_error "deploy rollback requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || {
    local code="$?"
    output_error "Application not found or invalid: $app" "$code"
    return "$code"
  }
  deploy_git_validate || {
    local code="$?"
    output_error "Application path must be a Git working tree for rollback: $APP_PATH" "$code"
    return "$code"
  }
  if [[ "$allow_dirty" -ne 1 ]] && deploy_git_dirty; then
    output_error "Working tree has uncommitted changes. Commit, stash, or use --allow-dirty." "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  fi

  if [[ -z "$target" ]]; then
    target="$(deploy_latest_previous_revision)" || {
      output_error "No deploy history with a previous revision for '$APP_NAME'" "$APPPILOT_ERR_CONFIG"
      return "$APPPILOT_ERR_CONFIG"
    }
  fi
  current_revision="$(deploy_git_revision)" || {
    output_error "Could not read current Git revision for '$APP_NAME'" "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  }

  actions+=("git reset --hard $target")
  if [[ "$APP_MANAGER" == "pm2" ]]; then
    actions+=("restart PM2 app")
  else
    actions+=("start Docker Compose project")
  fi
  actions+=("show status")

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"target\":$(json_string "$target"),\"current\":$(json_string "$current_revision"),\"actions\":$(deploy_json_actions "${actions[@]}")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would rollback: $APP_NAME"
      log_info "Current: $(deploy_short_revision "$current_revision")"
      log_info "Target:  $(deploy_short_revision "$target")"
      local action
      for action in "${actions[@]}"; do
        log_info "- $action"
      done
      log_info ""
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "deploy-rollback" "$APP_NAME" || return "$?"
  deploy_run_step "Rolled back Git revision" deploy_git_reset_hard "$target" || return "$?"
  if [[ "$APP_MANAGER" == "pm2" ]]; then
    deploy_restart_pm2 || return "$?"
  else
    compose_validate || {
      local code="$?"
      output_error "Docker Compose is unavailable" "$code"
      return "$code"
    }
    deploy_run_step "Docker Compose project started" compose_start || return "$?"
  fi

  deploy_record_history "rollback" "$current_revision" "$target" "-" "-" "rollback"
  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$APP_NAME"),\"rolledBack\":true,\"from\":$(json_string "$current_revision"),\"to\":$(json_string "$target")}"
  else
    log_check "Rollback completed for $APP_NAME"
    deploy_print_status
  fi
}
