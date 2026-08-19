#!/usr/bin/env bash

backup_app_dir_path() {
  printf '%s/%s' "$APPPILOT_BACKUPS_DIR" "$APP_NAME"
}

backup_ensure_app_dir() {
  mkdir -p "$(backup_app_dir_path)"
}

backup_snapshot_path() {
  local timestamp
  timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  printf '%s/%s-%s.tar.gz' "$(backup_app_dir_path)" "$APP_NAME" "$timestamp"
}

backup_json_actions() {
  local first=1 action
  printf '['
  for action in "$@"; do
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    json_string "$action"
  done
  printf ']'
}

backup_list_json_array() {
  local dir="$1"
  local file first=1
  printf '['
  if [[ -d "$dir" ]]; then
    for file in "$dir"/*.tar.gz; do
      [[ -e "$file" ]] || continue
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      json_string "$(basename "$file")"
    done
  fi
  printf ']'
}

backup_create_tar() {
  local output="$1"
  local include_env="$2"
  local parent base
  parent="$(dirname "$APP_PATH")"
  base="$(basename "$APP_PATH")"

  if [[ "$include_env" == "1" ]]; then
    tar -czf "$output" --exclude "$base/.git" --exclude "$base/node_modules" -C "$parent" "$base"
  else
    tar -czf "$output" --exclude "$base/.git" --exclude "$base/node_modules" --exclude "$base/.env" -C "$parent" "$base"
  fi
}

cmd_backup_snapshot() {
  local app="" include_env=0 output=""
  local -a actions=()
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --include-env) include_env=1; shift ;;
      --dry-run) APPPILOT_DRY_RUN=1; export APPPILOT_DRY_RUN; shift ;;
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "backup snapshot accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done

  [[ -n "$app" ]] || { output_error "backup snapshot requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || {
    local code="$?"
    output_error "Application not found or invalid: $app" "$code"
    return "$code"
  }
  output="$(backup_snapshot_path)"

  actions+=("create backup directory $(backup_app_dir_path)")
  actions+=("archive $APP_PATH to $output")
  [[ "$include_env" == "1" ]] || actions+=("exclude .env, .git, and node_modules")

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"path\":$(json_string "$output"),\"includeEnv\":$(json_bool "$include_env"),\"actions\":$(backup_json_actions "${actions[@]}")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would create backup snapshot: $APP_NAME"
      local action
      for action in "${actions[@]}"; do
        log_info "- $action"
      done
      log_info ""
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  command -v tar >/dev/null 2>&1 || {
    output_error "tar is required for backup snapshots" "$APPPILOT_ERR_MISSING_DEP"
    return "$APPPILOT_ERR_MISSING_DEP"
  }

  lock_acquire "backup" "$APP_NAME" || return "$?"
  backup_ensure_app_dir
  backup_create_tar "$output" "$include_env" || {
    local code="$?"
    output_error "Backup snapshot failed" "$code"
    return "$code"
  }
  chmod 600 "$output" 2>/dev/null || true

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$APP_NAME"),\"path\":$(json_string "$output"),\"includeEnv\":$(json_bool "$include_env"),\"created\":true}"
  else
    log_check "Backup snapshot created"
    log_info "Path: $output"
  fi
}

cmd_backup_list() {
  local app="" dir
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "backup list accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done

  [[ -n "$app" ]] || { output_error "backup list requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || {
    local code="$?"
    output_error "Application not found or invalid: $app" "$code"
    return "$code"
  }
  dir="$APPPILOT_BACKUPS_DIR/$APP_NAME"

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$APP_NAME"),\"snapshots\":$(backup_list_json_array "$dir")}"
    return "$APPPILOT_OK"
  fi

  ui_title "Backup Snapshots"
  printf '\n'
  if [[ ! -d "$dir" ]] || ! compgen -G "$dir/*.tar.gz" >/dev/null; then
    log_info "No backup snapshots for $APP_NAME"
    return "$APPPILOT_OK"
  fi
  local file
  for file in "$dir"/*.tar.gz; do
    [[ -e "$file" ]] || continue
    printf '  %s\n' "$(basename "$file")"
  done
}

cmd_backup() {
  local subcommand="${1:-}"
  shift || true
  case "$subcommand" in
    snapshot) cmd_backup_snapshot "$@" ;;
    list) cmd_backup_list "$@" ;;
    *) output_error "backup supports only: snapshot, list" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
  esac
}
