#!/usr/bin/env bash

clone_default_path() {
  local name="$1"
  printf '%s/apps/%s' "$HOME" "$name"
}

clone_json_actions() {
  local first=1 action
  printf '['
  for action in "$@"; do
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    json_string "$action"
  done
  printf ']'
}

clone_fail_from_file() {
  local message="$1"
  local code="$2"
  local file="$3"
  local detail=""
  [[ -s "$file" ]] && detail="$(tr '\n' ' ' <"$file")"
  [[ -n "$detail" ]] && message="$message: $detail"
  output_error "$message" "$code"
  return "$code"
}

clone_git_clone() {
  local repo="$1"
  local destination="$2"
  local branch="$3"
  if [[ -n "$branch" ]]; then
    git clone --branch "$branch" --single-branch "$repo" "$destination"
  else
    git clone "$repo" "$destination"
  fi
}

clone_run_git() {
  local repo="$1"
  local destination="$2"
  local branch="$3"
  local tmp code
  tmp="$(mktemp)"
  if clone_git_clone "$repo" "$destination" "$branch" >"$tmp" 2>&1; then
    if [[ "${APPPILOT_QUIET:-0}" != "1" ]]; then
      [[ -s "$tmp" ]] && cat "$tmp"
      log_check "Cloned $repo"
    fi
    rm -f "$tmp"
    return "$APPPILOT_OK"
  fi
  code="$?"
  clone_fail_from_file "Git clone failed" "$code" "$tmp"
  rm -f "$tmp"
  return "$code"
}

clone_print_next_steps() {
  local name="$1"
  local destination="$2"
  [[ "${APPPILOT_JSON:-0}" == "1" || "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  printf 'Path: %s\n\n' "$destination"
  printf 'Next:\n'
  printf '  cd %s\n' "$destination"
  printf '  apppilot add\n'
  printf '  apppilot env init %s\n' "$name"
  printf '  apppilot deploy %s --dry-run\n' "$name"
}

cmd_clone() {
  local repo="" name="" destination="" branch=""
  local -a actions=()

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --path)
        [[ -n "${2:-}" ]] || { output_error "--path requires a destination path" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        destination="$2"
        shift 2
        ;;
      --branch)
        [[ -n "${2:-}" ]] || { output_error "--branch requires a branch name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        branch="$2"
        shift 2
        ;;
      --dry-run) APPPILOT_DRY_RUN=1; export APPPILOT_DRY_RUN; shift ;;
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      --non-interactive) APPPILOT_NON_INTERACTIVE=1; export APPPILOT_NON_INTERACTIVE; shift ;;
      *)
        if [[ -z "$repo" ]]; then
          repo="$1"
        elif [[ -z "$name" ]]; then
          name="$1"
        else
          output_error "clone accepts: <repo> <name>" "$APPPILOT_ERR_ARGS"
          return "$APPPILOT_ERR_ARGS"
        fi
        shift
        ;;
    esac
  done

  [[ -n "$repo" ]] || { output_error "clone requires a repository URL" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ -n "$name" ]] || { output_error "clone requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  validator_name "$name" || { output_error "Invalid application name: $name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }

  [[ -n "$destination" ]] || destination="$(clone_default_path "$name")"
  validator_path_safe "$destination" || {
    output_error "Clone destination must be an absolute safe path: $destination" "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  }
  [[ ! -e "$destination" ]] || {
    output_error "Clone destination already exists: $destination" "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  }

  actions+=("create parent directory $(dirname "$destination")")
  if [[ -n "$branch" ]]; then
    actions+=("git clone --branch $branch --single-branch $repo $destination")
  else
    actions+=("git clone $repo $destination")
  fi
  actions+=("run apppilot add from the cloned project")

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"repo\":$(json_string "$repo"),\"name\":$(json_string "$name"),\"path\":$(json_string "$destination"),\"branch\":$(json_string "$branch"),\"actions\":$(clone_json_actions "${actions[@]}")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would clone: $name"
      local action
      for action in "${actions[@]}"; do
        log_info "- $action"
      done
      log_info ""
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  command -v git >/dev/null 2>&1 || {
    output_error "Git is required. Run: apppilot adapters install git" "$APPPILOT_ERR_MISSING_DEP"
    return "$APPPILOT_ERR_MISSING_DEP"
  }

  mkdir -p "$(dirname "$destination")"
  clone_run_git "$repo" "$destination" "$branch" || return "$?"

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"repo\":$(json_string "$repo"),\"name\":$(json_string "$name"),\"path\":$(json_string "$destination"),\"branch\":$(json_string "$branch"),\"cloned\":true}"
  else
    clone_print_next_steps "$name" "$destination"
  fi
}
