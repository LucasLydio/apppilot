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
  printf '\n'
}

add_collect_guided() {
  local ref_name="$1"
  local ref_manager="$2"
  local ref_path="$3"
  local ref_entrypoint="$4"
  local ref_compose_file="$5"
  local ref_environment="$6"
  local confirm_status=0 validation_status=0 default_value=""

  while true; do
    ui_banner
    ui_section "Add Application"
    log_info "Press Enter to accept a value shown in brackets."
    printf '\n'

    add_prompt_value ref_name "Name" "$ref_name" || return "$?"

    while true; do
      [[ -n "$ref_manager" ]] || ref_manager="pm2"
      add_prompt_value ref_manager "Manager (pm2/compose)" "$ref_manager" || return "$?"
      case "$ref_manager" in
        pm2|compose) break ;;
        *) log_warn "Manager must be pm2 or compose." ;;
      esac
    done

    [[ -n "$ref_path" ]] || ref_path="$PWD"
    add_prompt_value ref_path "Project path" "$ref_path" || return "$?"

    if [[ "$ref_manager" == "pm2" ]]; then
      if [[ -z "$ref_entrypoint" ]]; then
        default_value="$(add_default_entrypoint "$ref_path")"
        ref_entrypoint="$default_value"
      fi
      add_prompt_value ref_entrypoint "Entrypoint" "$ref_entrypoint" || return "$?"
      ref_compose_file=""
    else
      if [[ -z "$ref_compose_file" ]]; then
        default_value="$(add_default_compose_file "$ref_path")"
        ref_compose_file="$default_value"
      fi
      add_prompt_value ref_compose_file "Compose file" "$ref_compose_file" || return "$?"
      ref_entrypoint=""
    fi

    [[ -n "$ref_environment" ]] || ref_environment="production"
    add_prompt_value ref_environment "Environment" "$ref_environment" || return "$?"

    add_print_summary "$ref_name" "$ref_manager" "$ref_path" "$ref_entrypoint" "$ref_compose_file" "$ref_environment"
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

  if add_should_prompt; then
    local guided_status=0
    if add_collect_guided "$name" "$manager" "$path" "$entrypoint" "$compose_file" "$environment"; then
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

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
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
    case "$code" in
      "$APPPILOT_ERR_ARGS") output_error "Invalid application registration arguments for '$name'" "$code" ;;
      "$APPPILOT_ERR_CONFIG") output_error "Invalid application configuration for '$name'" "$code" ;;
      *) output_error "Could not register application '$name'" "$code" ;;
    esac
    return "$code"
  }

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$name"),\"manager\":$(json_string "$manager")}"
  else
    log_check "Registered $name ($manager)"
  fi
}
