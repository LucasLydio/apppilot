#!/usr/bin/env bash

deploy_json_actions() {
  local first=1 action
  printf '['
  for action in "$@"; do
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    json_string "$action"
  done
  printf ']'
}

deploy_fail_from_file() {
  local message="$1"
  local code="$2"
  local file="$3"
  local detail=""
  [[ -s "$file" ]] && detail="$(tr '\n' ' ' <"$file")"
  [[ -n "$detail" ]] && message="$message: $detail"
  output_error "$message" "$code"
  return "$code"
}

deploy_run_step() {
  local label="$1"
  shift
  local tmp code
  tmp="$(mktemp)"
  if "$@" >"$tmp" 2>&1; then
    if [[ "${APPPILOT_QUIET:-0}" != "1" ]]; then
      log_check "$label"
      [[ -s "$tmp" ]] && cat "$tmp"
    fi
    rm -f "$tmp"
    return "$APPPILOT_OK"
  else
    code="$?"
    deploy_fail_from_file "$label failed" "$code" "$tmp"
    rm -f "$tmp"
    return "$code"
  fi
}

deploy_git_validate() {
  command -v git >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
  (cd "$APP_PATH" && git rev-parse --is-inside-work-tree >/dev/null 2>&1) || return "$APPPILOT_ERR_CONFIG"
}

deploy_git_dirty() {
  [[ -n "$(cd "$APP_PATH" && git status --porcelain)" ]]
}

deploy_git_pull() {
  local remote="$1"
  local branch="$2"
  (cd "$APP_PATH" && git pull "$remote" "$branch")
}

deploy_git_revision() {
  (cd "$APP_PATH" && git rev-parse HEAD)
}

deploy_git_reset_hard() {
  local revision="$1"
  (cd "$APP_PATH" && git reset --hard "$revision")
}

deploy_history_file() {
  mkdir -p "$APPPILOT_DEPLOYS_DIR"
  printf '%s/%s.tsv' "$APPPILOT_DEPLOYS_DIR" "$APP_NAME"
}

deploy_record_history() {
  local result="$1"
  local before="$2"
  local after="$3"
  local remote="$4"
  local branch="$5"
  local stage="$6"
  local file timestamp
  file="$(deploy_history_file)"
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  [[ -n "$before" ]] || before="-"
  [[ -n "$after" ]] || after="-"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$timestamp" "$result" "$APP_NAME" "$APP_MANAGER" "$remote" "$branch" "$before" "$after" "$stage" >>"$file"
  chmod 600 "$file" 2>/dev/null || true
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

deploy_package_manager() {
  if [[ -f "$APP_PATH/pnpm-lock.yaml" ]]; then
    printf '%s\n' "pnpm"
  elif [[ -f "$APP_PATH/yarn.lock" ]]; then
    printf '%s\n' "yarn"
  elif [[ -f "$APP_PATH/package.json" ]]; then
    printf '%s\n' "npm"
  fi
}

deploy_package_script_exists() {
  local script="$1"
  [[ -f "$APP_PATH/package.json" ]] || return 1
  grep -Eq "\"$script\"[[:space:]]*:" "$APP_PATH/package.json"
}

deploy_install_deps() {
  local manager="$1"
  case "$manager" in
    pnpm) (cd "$APP_PATH" && pnpm install --frozen-lockfile) ;;
    yarn) (cd "$APP_PATH" && yarn install --frozen-lockfile) ;;
    npm)
      if [[ -f "$APP_PATH/package-lock.json" || -f "$APP_PATH/npm-shrinkwrap.json" ]]; then
        (cd "$APP_PATH" && npm ci)
      else
        (cd "$APP_PATH" && npm install)
      fi
      ;;
    *) return "$APPPILOT_ERR_MISSING_DEP" ;;
  esac
}

deploy_run_package_script() {
  local manager="$1"
  local script="$2"
  case "$manager" in
    pnpm) (cd "$APP_PATH" && pnpm run "$script") ;;
    yarn) (cd "$APP_PATH" && yarn run "$script") ;;
    npm) (cd "$APP_PATH" && npm run "$script") ;;
    *) return "$APPPILOT_ERR_MISSING_DEP" ;;
  esac
}

deploy_restart_pm2() {
  local tmp code
  tmp="$(mktemp)"
  if pm2_restart >"$tmp" 2>&1; then
    [[ "${APPPILOT_QUIET:-0}" == "1" ]] || { log_check "Restarted $APP_NAME with PM2"; cat "$tmp"; }
    rm -f "$tmp"
    return "$APPPILOT_OK"
  else
    code="$?"
  fi
  rm -f "$tmp"
  if [[ "$code" -eq "$APPPILOT_ERR_MISSING_DEP" ]]; then
    return "$code"
  fi
  tmp="$(mktemp)"
  if pm2_start >"$tmp" 2>&1; then
    [[ "${APPPILOT_QUIET:-0}" == "1" ]] || { log_check "Started $APP_NAME with PM2"; cat "$tmp"; }
    rm -f "$tmp"
    return "$APPPILOT_OK"
  fi
  code="$?"
  deploy_fail_from_file "PM2 restart/start failed" "$code" "$tmp"
  rm -f "$tmp"
  return "$code"
}

deploy_compose_build() {
  docker compose -f "$APP_PATH/$APP_COMPOSE_FILE" -p "$APP_NAME" build
}

deploy_print_status() {
  local tmp
  [[ "${APPPILOT_JSON:-0}" == "1" || "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  tmp="$(mktemp)"
  if adapter_status_details >"$tmp" 2>/dev/null; then
    printf '\n'
    status_print_table "$tmp"
  fi
  rm -f "$tmp"
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

cmd_deploy() {
  case "${1:-}" in
    history) shift; cmd_deploy_history "$@"; return "$?" ;;
    rollback) shift; cmd_deploy_rollback "$@"; return "$?" ;;
  esac

  local app="" remote="origin" branch="main" skip_tests=0 skip_install=0 skip_build=0 allow_dirty=0
  local package_manager="" has_tests=0 has_build=0
  local previous_revision="" pulled_revision="" deploy_stage=""
  local -a actions=()

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --remote) remote="${2:-origin}"; shift 2 ;;
      --branch) branch="${2:-main}"; shift 2 ;;
      --skip-tests) skip_tests=1; shift ;;
      --skip-install) skip_install=1; shift ;;
      --skip-build) skip_build=1; shift ;;
      --allow-dirty) allow_dirty=1; shift ;;
      --dry-run) APPPILOT_DRY_RUN=1; export APPPILOT_DRY_RUN; shift ;;
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "deploy accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done

  [[ -n "$app" ]] || { output_error "deploy requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  registry_load "$app" || {
    local code="$?"
    output_error "Application not found or invalid: $app" "$code"
    return "$code"
  }

  deploy_git_validate || {
    local code="$?"
    output_error "Application path must be a Git working tree for deploy: $APP_PATH" "$code"
    return "$code"
  }

  if [[ "$allow_dirty" -ne 1 ]] && deploy_git_dirty; then
    output_error "Working tree has uncommitted changes. Commit, stash, or use --allow-dirty." "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  fi

  previous_revision="$(deploy_git_revision)" || {
    output_error "Could not read current Git revision for '$APP_NAME'" "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  }

  package_manager="$(deploy_package_manager)"
  if [[ -n "$package_manager" ]]; then
    deploy_package_script_exists test && has_tests=1
    deploy_package_script_exists build && has_build=1
  fi

  actions+=("check Git working tree")
  actions+=("git pull $remote $branch")
  if [[ -n "$package_manager" && "$skip_install" -ne 1 ]]; then
    actions+=("install dependencies with $package_manager")
  fi
  if [[ -n "$package_manager" && "$has_tests" -eq 1 && "$skip_tests" -ne 1 ]]; then
    actions+=("run test script")
  fi
  if [[ "$APP_MANAGER" == "pm2" && -n "$package_manager" && "$has_build" -eq 1 && "$skip_build" -ne 1 ]]; then
    actions+=("run build script")
  elif [[ "$APP_MANAGER" == "compose" && "$skip_build" -ne 1 ]]; then
    actions+=("build Docker Compose project")
  fi
  if [[ "$APP_MANAGER" == "pm2" ]]; then
    actions+=("restart PM2 app")
  else
    actions+=("start Docker Compose project")
  fi
  actions+=("show status")

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"manager\":$(json_string "$APP_MANAGER"),\"remote\":$(json_string "$remote"),\"branch\":$(json_string "$branch"),\"actions\":$(deploy_json_actions "${actions[@]}")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would deploy: $APP_NAME"
      log_info "Remote: $remote"
      log_info "Branch: $branch"
      local action
      for action in "${actions[@]}"; do
        log_info "- $action"
      done
      log_info ""
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "deploy" "$APP_NAME" || return "$?"

  deploy_stage="pull"
  deploy_run_step "Pulled $remote $branch" deploy_git_pull "$remote" "$branch" || {
    local code="$?"
    deploy_record_history "failed" "$previous_revision" "$previous_revision" "$remote" "$branch" "$deploy_stage"
    return "$code"
  }
  pulled_revision="$(deploy_git_revision)" || pulled_revision="$previous_revision"

  if [[ -n "$package_manager" && "$skip_install" -ne 1 ]]; then
    deploy_stage="install"
    deploy_run_step "Installed dependencies with $package_manager" deploy_install_deps "$package_manager" || {
      local code="$?"
      deploy_record_history "failed" "$previous_revision" "$pulled_revision" "$remote" "$branch" "$deploy_stage"
      return "$code"
    }
  fi

  if [[ -n "$package_manager" && "$has_tests" -eq 1 && "$skip_tests" -ne 1 ]]; then
    deploy_stage="test"
    deploy_run_step "Test script" deploy_run_package_script "$package_manager" "test" || {
      local code="$?"
      deploy_record_history "failed" "$previous_revision" "$pulled_revision" "$remote" "$branch" "$deploy_stage"
      return "$code"
    }
  fi

  if [[ "$APP_MANAGER" == "pm2" ]]; then
    if [[ -n "$package_manager" && "$has_build" -eq 1 && "$skip_build" -ne 1 ]]; then
      deploy_stage="build"
      deploy_run_step "Build completed" deploy_run_package_script "$package_manager" "build" || {
        local code="$?"
        deploy_record_history "failed" "$previous_revision" "$pulled_revision" "$remote" "$branch" "$deploy_stage"
        return "$code"
      }
    fi
    deploy_stage="restart"
    deploy_restart_pm2 || {
      local code="$?"
      deploy_record_history "failed" "$previous_revision" "$pulled_revision" "$remote" "$branch" "$deploy_stage"
      return "$code"
    }
  else
    compose_validate || {
      local code="$?"
      deploy_record_history "failed" "$previous_revision" "$pulled_revision" "$remote" "$branch" "compose-validate"
      output_error "Docker Compose is unavailable" "$code"
      return "$code"
    }
    if [[ "$skip_build" -ne 1 ]]; then
      deploy_stage="compose-build"
      deploy_run_step "Docker Compose build completed" deploy_compose_build || {
        local code="$?"
        deploy_record_history "failed" "$previous_revision" "$pulled_revision" "$remote" "$branch" "$deploy_stage"
        return "$code"
      }
    fi
    deploy_stage="compose-up"
    deploy_run_step "Docker Compose project started" compose_start || {
      local code="$?"
      deploy_record_history "failed" "$previous_revision" "$pulled_revision" "$remote" "$branch" "$deploy_stage"
      return "$code"
    }
  fi

  deploy_record_history "success" "$previous_revision" "$pulled_revision" "$remote" "$branch" "complete"

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$APP_NAME"),\"manager\":$(json_string "$APP_MANAGER"),\"remote\":$(json_string "$remote"),\"branch\":$(json_string "$branch"),\"before\":$(json_string "$previous_revision"),\"after\":$(json_string "$pulled_revision"),\"deployed\":true,\"actions\":$(deploy_json_actions "${actions[@]}")}"
  else
    log_check "Deploy completed for $APP_NAME"
    deploy_print_status
  fi
}
