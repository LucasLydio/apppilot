#!/usr/bin/env bash

add_should_prompt() {
  [[ "${APPPILOT_NON_INTERACTIVE:-0}" != "1" ]] || return 1
  [[ "${APPPILOT_JSON:-0}" != "1" ]] || return 1
  [[ -t 0 || "${APPPILOT_FORCE_INTERACTIVE:-0}" == "1" ]]
}

add_prompt_value() {
  local variable="$1"
  local label="$2"
  local current="${3:-}"
  local answer="" prompt="$label"

  [[ -n "$current" ]] && prompt="$label [$current]"
  printf '%s: ' "$prompt"
  if ! IFS= read -r answer; then
    return "$APPPILOT_ERR_ARGS"
  fi
  [[ -n "$answer" ]] || answer="$current"
  printf -v "$variable" '%s' "$answer"
}

add_prompt_tip() {
  log_info "$1"
  [[ -n "${2:-}" ]] && log_info "Example: $2"
}

add_prompt_name() {
  local variable="$1"
  local current="$2"
  local value="$current"
  local file

  while true; do
    add_prompt_tip "Use a short unique app name. Letters, numbers, dashes, and underscores are allowed." "users-api"
    add_prompt_value value "Name" "$value" || return "$?"
    if ! validator_name "$value"; then
      log_warn "Name must start with a letter or number and use only letters, numbers, dashes, or underscores."
      value="$current"
      continue
    fi
    file="$(app_config_file_for "$value")"
    if [[ -e "$file" ]]; then
      log_warn "An application named '$value' is already registered. Choose another name."
      value=""
      continue
    fi
    printf -v "$variable" '%s' "$value"
    return 0
  done
}

add_prompt_manager() {
  local variable="$1"
  local current="$2"
  local value="$current"

  while true; do
    [[ -n "$value" ]] || value="pm2"
    add_prompt_tip "Choose how AppPilot will manage this project. Use pm2 for Node processes or compose for Docker Compose apps." "pm2"
    add_prompt_value value "Manager (pm2/compose)" "$value" || return "$?"
    if validator_manager "$value"; then
      printf -v "$variable" '%s' "$value"
      return 0
    fi
    log_warn "Manager must be exactly 'pm2' or 'compose'."
    value="pm2"
  done
}

add_prompt_project_path() {
  local variable="$1"
  local current="$2"
  local value="$current"

  while true; do
    [[ -n "$value" ]] || value="$PWD"
    add_prompt_tip "Use the absolute path to the project folder that already exists on this server." "$HOME/apps/users-api"
    add_prompt_value value "Project path" "$value" || return "$?"
    if ! validator_path_safe "$value"; then
      log_warn "Path must be an absolute path like '$HOME/apps/users-api' and cannot contain '..'."
      value=""
      continue
    fi
    if [[ ! -d "$value" ]]; then
      log_warn "Project path does not exist yet. Clone or create the project folder first."
      value=""
      continue
    fi
    printf -v "$variable" '%s' "$value"
    return 0
  done
}

add_prompt_entrypoint() {
  local variable="$1"
  local current="$2"
  local project_path="$3"
  local value="$current"

  while true; do
    add_prompt_tip "Use the PM2 entry file relative to the project folder. Do not start with '/'." "dist/main.js"
    add_prompt_value value "Entrypoint" "$value" || return "$?"
    if ! validator_relative_path_safe "$value"; then
      log_warn "Entrypoint must be a relative file path and cannot contain '..'."
      value="$current"
      continue
    fi
    if [[ ! -f "$project_path/$value" || -L "$project_path/$value" ]]; then
      log_warn "Entrypoint was not found inside the project folder."
      value="$current"
      continue
    fi
    printf -v "$variable" '%s' "$value"
    return 0
  done
}

add_prompt_compose_file() {
  local variable="$1"
  local current="$2"
  local project_path="$3"
  local value="$current"

  while true; do
    add_prompt_tip "Use the Compose file relative to the project folder. Common names are compose.yaml or docker-compose.yml." "compose.yaml"
    add_prompt_value value "Compose file" "$value" || return "$?"
    if ! validator_relative_path_safe "$value"; then
      log_warn "Compose file must be a relative file path and cannot contain '..'."
      value="$current"
      continue
    fi
    if [[ ! -f "$project_path/$value" || -L "$project_path/$value" ]]; then
      log_warn "Compose file was not found inside the project folder."
      value="$current"
      continue
    fi
    printf -v "$variable" '%s' "$value"
    return 0
  done
}

add_prompt_environment() {
  local variable="$1"
  local current="$2"
  local value="$current"

  while true; do
    [[ -n "$value" ]] || value="production"
    add_prompt_tip "Use a label for this app's runtime environment." "production"
    add_prompt_value value "Environment" "$value" || return "$?"
    if [[ -n "$value" ]]; then
      printf -v "$variable" '%s' "$value"
      return 0
    fi
    log_warn "Environment cannot be empty."
    value="production"
  done
}

add_env_example_available() {
  local project_path="$1"
  env_example_available "$project_path"
}

add_prompt_env_from_example() {
  local variable="$1"
  local project_path="$2"
  local current="${3:-ask}"
  local answer=""

  printf -v "$variable" '%s' "skip"
  add_env_example_available "$project_path" || return 0

  case "$current" in
    copy)
      printf -v "$variable" '%s' "copy"
      return 0
      ;;
    skip) return 0 ;;
  esac

  add_prompt_tip "Found .env.example and no .env. AppPilot can copy it as a starter file with 600 permissions." ".env"
  while true; do
    printf 'Create .env from .env.example? [Y/n] '
    if ! IFS= read -r answer; then
      return "$APPPILOT_ERR_ARGS"
    fi
    case "$answer" in
      ""|y|Y|yes|YES|Yes)
        printf -v "$variable" '%s' "copy"
        return 0
        ;;
      n|N|no|NO|No)
        printf -v "$variable" '%s' "skip"
        return 0
        ;;
      *) log_warn "Choose y to create .env or n to skip." ;;
    esac
  done
}

add_default_entrypoint() {
  local path="$1"
  local candidate
  for candidate in dist/main.js server.js index.js app.js main.js; do
    if [[ -f "$path/$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
}

add_default_compose_file() {
  local path="$1"
  local candidate
  for candidate in compose.yaml docker-compose.yml docker-compose.yaml compose.yml; do
    if [[ -f "$path/$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
}

add_confirm_registration() {
  local answer=""
  while true; do
    printf 'Register this application? [Y/r/n] '
    if ! IFS= read -r answer; then
      return "$APPPILOT_ERR_ARGS"
    fi
    case "$answer" in
      ""|y|Y|yes|YES|Yes) return 0 ;;
      r|R|redo|REDO|Redo|edit|EDIT|Edit) return 10 ;;
      n|N|no|NO|No) return 11 ;;
      *) log_warn "Choose y to register, r to redo, or n to cancel." ;;
    esac
  done
}

add_retry_after_invalid_answers() {
  local answer=""
  while true; do
    printf 'Edit answers and try again? [Y/n] '
    if ! IFS= read -r answer; then
      return "$APPPILOT_ERR_ARGS"
    fi
    case "$answer" in
      ""|y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No) return 11 ;;
      *) log_warn "Choose y to edit or n to cancel." ;;
    esac
  done
}

add_print_summary() {
  local name="$1"
  local manager="$2"
  local path="$3"
  local entrypoint="$4"
  local compose_file="$5"
  local environment="$6"
  local env_action="${7:-skip}"

  ui_section "Review Application"
  ui_kv "Name" "$name"
  ui_kv "Manager" "$manager"
  ui_kv "Path" "$path"
  if [[ "$manager" == "compose" ]]; then
    ui_kv "Compose file" "$compose_file"
  else
    ui_kv "Entrypoint" "$entrypoint"
  fi
  ui_kv "Environment" "$environment"
  if [[ "$env_action" == "copy" ]]; then
    ui_kv ".env" "create from .env.example"
  fi
  printf '\n'
}

add_collect_guided() {
  local ref_name="$1"
  local ref_manager="$2"
  local ref_path="$3"
  local ref_entrypoint="$4"
  local ref_compose_file="$5"
  local ref_environment="$6"
  local ref_env_action="$7"
  local confirm_status=0 validation_status=0 default_value=""

  while true; do
    ui_banner
    ui_section "Add Application"
    log_info "Press Enter to accept a value shown in brackets."
    printf '\n'

    add_prompt_name ref_name "$ref_name" || return "$?"
    printf '\n'
    add_prompt_manager ref_manager "$ref_manager" || return "$?"
    printf '\n'
    add_prompt_project_path ref_path "$ref_path" || return "$?"
    printf '\n'

    if [[ "$ref_manager" == "pm2" ]]; then
      if [[ -z "$ref_entrypoint" ]]; then
        default_value="$(add_default_entrypoint "$ref_path")"
        ref_entrypoint="$default_value"
      fi
      add_prompt_entrypoint ref_entrypoint "$ref_entrypoint" "$ref_path" || return "$?"
      ref_compose_file=""
    else
      if [[ -z "$ref_compose_file" ]]; then
        default_value="$(add_default_compose_file "$ref_path")"
        ref_compose_file="$default_value"
      fi
      add_prompt_compose_file ref_compose_file "$ref_compose_file" "$ref_path" || return "$?"
      ref_entrypoint=""
    fi
    printf '\n'

    add_prompt_environment ref_environment "$ref_environment" || return "$?"
    printf '\n'
    add_prompt_env_from_example ref_env_action "$ref_path" "$ref_env_action" || return "$?"

    add_print_summary "$ref_name" "$ref_manager" "$ref_path" "$ref_entrypoint" "$ref_compose_file" "$ref_environment" "$ref_env_action"
    if add_confirm_registration; then
      confirm_status=0
    else
      confirm_status="$?"
    fi
    case "$confirm_status" in
      0) ;;
      10) continue ;;
      11)
        log_info "Canceled. No changes were made."
        return 11
        ;;
      *) return "$confirm_status" ;;
    esac

    if registry_validate_new "$ref_name" "$ref_manager" "$ref_path" "$ref_entrypoint" "$ref_compose_file"; then
      APPPILOT_ADD_NAME="$ref_name"
      APPPILOT_ADD_MANAGER="$ref_manager"
      APPPILOT_ADD_PATH="$ref_path"
      APPPILOT_ADD_ENTRYPOINT="$ref_entrypoint"
      APPPILOT_ADD_COMPOSE_FILE="$ref_compose_file"
      APPPILOT_ADD_ENVIRONMENT="$ref_environment"
      APPPILOT_ADD_ENV_ACTION="$ref_env_action"
      return 0
    fi
    validation_status="$?"

    case "$validation_status" in
      "$APPPILOT_ERR_ARGS") log_warn "Some answers are invalid. Check the name, manager, path, and file values." ;;
      "$APPPILOT_ERR_CONFIG") log_warn "AppPilot could not validate this project. Check that the path and app file exist, and that the name is not already registered." ;;
      *) log_warn "AppPilot could not register this application." ;;
    esac
    if add_retry_after_invalid_answers; then
      confirm_status=0
    else
      confirm_status="$?"
    fi
    case "$confirm_status" in
      0) ;;
      11)
        log_info "Canceled. No changes were made."
        return 11
        ;;
      *) return "$confirm_status" ;;
    esac
  done
}

cmd_add() {
  local name="" manager="" path="" entrypoint="" compose_file="" environment="production" env_action="ask"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --name) name="${2:-}"; shift 2 ;;
      --manager) manager="${2:-}"; shift 2 ;;
      --path) path="${2:-}"; shift 2 ;;
      --entrypoint) entrypoint="${2:-}"; shift 2 ;;
      --compose-file) compose_file="${2:-}"; shift 2 ;;
      --environment) environment="${2:-production}"; shift 2 ;;
      --env-from-example) env_action="copy"; shift ;;
      --no-env-from-example) env_action="skip"; shift ;;
      *) output_error "Unknown add argument: $1" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
    esac
  done

  if add_should_prompt; then
    local guided_status=0
    if add_collect_guided "$name" "$manager" "$path" "$entrypoint" "$compose_file" "$environment" "$env_action"; then
      guided_status=0
    else
      guided_status="$?"
    fi
    case "$guided_status" in
      0) ;;
      11) return "$APPPILOT_OK" ;;
      *) return "$guided_status" ;;
    esac
    name="$APPPILOT_ADD_NAME"
    manager="$APPPILOT_ADD_MANAGER"
    path="$APPPILOT_ADD_PATH"
    entrypoint="$APPPILOT_ADD_ENTRYPOINT"
    compose_file="$APPPILOT_ADD_COMPOSE_FILE"
    environment="$APPPILOT_ADD_ENVIRONMENT"
    env_action="$APPPILOT_ADD_ENV_ACTION"
  fi

  [[ -n "$name" && -n "$manager" && -n "$path" ]] || {
    output_error "add requires --name, --manager, and --path" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"
  }

  registry_validate_new "$name" "$manager" "$path" "$entrypoint" "$compose_file" || {
    local code="$?"
    case "$code" in
      "$APPPILOT_ERR_ARGS") output_error "Invalid application registration arguments for '$name'" "$code" ;;
      "$APPPILOT_ERR_CONFIG") output_error "Invalid application configuration for '$name'" "$code" ;;
      *) output_error "Could not register application '$name'" "$code" ;;
    esac
    return "$code"
  }

  [[ "$env_action" == "ask" ]] && env_action="skip"

  if [[ "$env_action" == "copy" ]]; then
    if ! add_env_example_available "$path"; then
      output_error "Cannot create .env from .env.example for '$name'" "$APPPILOT_ERR_CONFIG"
      return "$APPPILOT_ERR_CONFIG"
    fi
  fi

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      if [[ "$env_action" == "copy" ]]; then
        output_success_json "{\"actions\":[\"create .env from .env.example\",\"register application $(json_escape "$name")\"]}" "[]" "true"
      else
        output_success_json "{\"actions\":[\"register application $(json_escape "$name")\"]}" "[]" "true"
      fi
    else
      output_dry_run_header
      if [[ "$env_action" == "copy" ]]; then
        log_info "Would create .env from .env.example"
      fi
      log_info "Would register application: $name"
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "add" "$name" || return "$?"
  if [[ "$env_action" == "copy" ]]; then
    env_create_from_example "$path" || {
      local code="$?"
      output_error "Could not create .env from .env.example for '$name'" "$code"
      return "$code"
    }
  fi
  registry_add "$name" "$manager" "$path" "$entrypoint" "$compose_file" "$environment" || {
    local code="$?"
    case "$code" in
      "$APPPILOT_ERR_ARGS") output_error "Invalid application registration arguments for '$name'" "$code" ;;
      "$APPPILOT_ERR_CONFIG") output_error "Invalid application configuration for '$name'" "$code" ;;
      *) output_error "Could not register application '$name'" "$code" ;;
    esac
    return "$code"
  }

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    local env_created="false"
    [[ "$env_action" == "copy" ]] && env_created="true"
    output_success_json "{\"app\":$(json_string "$name"),\"manager\":$(json_string "$manager"),\"envCreated\":$(json_bool "$env_created")}"
  else
    if [[ "$env_action" == "copy" ]]; then
      log_check "Created .env from .env.example"
    fi
    log_check "Registered $name ($manager)"
  fi
}
