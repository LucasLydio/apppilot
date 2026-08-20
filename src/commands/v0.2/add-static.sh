#!/usr/bin/env bash

add_static_default_build_dir() {
  local path="$1"
  local candidate
  for candidate in dist build public; do
    if [[ -d "$path/$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  printf 'dist'
}

add_static_prompt_build_dir() {
  local variable="$1"
  local project_path="$2"
  local current="$3"
  local value="$current"

  while true; do
    [[ -n "$value" ]] || value="$(add_static_default_build_dir "$project_path")"
    add_prompt_tip "Use the frontend build output folder relative to the project path." "dist"
    add_prompt_value value "Build directory" "$value" || return "$?"
    if ! validator_relative_path_safe "$value"; then
      log_warn "Build directory must be a relative path and cannot contain '..'."
      value=""
      continue
    fi
    if [[ ! -d "$project_path/$value" || -L "$project_path/$value" ]]; then
      log_warn "Build directory was not found inside the project folder. Run the frontend build first."
      value=""
      continue
    fi
    printf -v "$variable" '%s' "$value"
    return 0
  done
}

add_static_print_summary() {
  local name="$1"
  local path="$2"
  local build_dir="$3"
  local environment="$4"
  local env_action="${5:-skip}"

  ui_section "Review Static Application"
  ui_kv "Name" "$name"
  ui_kv "Manager" "static"
  ui_kv "Path" "$path"
  ui_kv "Build directory" "$build_dir"
  ui_kv "Environment" "$environment"
  if [[ "$env_action" == "copy" ]]; then
    ui_kv ".env" "create from .env.example"
  fi
  printf '\n'
}

add_static_collect_guided() {
  local ref_name="$1"
  local ref_path="$2"
  local ref_build_dir="$3"
  local ref_environment="$4"
  local ref_env_action="$5"
  local confirm_status=0 validation_status=0

  while true; do
    ui_banner
    ui_section "Add Static Application"
    log_info "Use this for frontend apps served by Nginx from a build folder."
    log_info "Press Enter to accept a value shown in brackets."
    printf '\n'

    add_prompt_name ref_name "$ref_name" || return "$?"
    printf '\n'
    add_prompt_project_path ref_path "$ref_path" || return "$?"
    printf '\n'
    add_static_prompt_build_dir ref_build_dir "$ref_path" "$ref_build_dir" || return "$?"
    printf '\n'
    add_prompt_environment ref_environment "$ref_environment" || return "$?"
    printf '\n'
    add_prompt_env_from_example ref_env_action "$ref_path" "$ref_env_action" || return "$?"

    add_static_print_summary "$ref_name" "$ref_path" "$ref_build_dir" "$ref_environment" "$ref_env_action"
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

    if registry_validate_new "$ref_name" "static" "$ref_path" "" "" "$ref_build_dir"; then
      APPPILOT_ADD_STATIC_NAME="$ref_name"
      APPPILOT_ADD_STATIC_PATH="$ref_path"
      APPPILOT_ADD_STATIC_BUILD_DIR="$ref_build_dir"
      APPPILOT_ADD_STATIC_ENVIRONMENT="$ref_environment"
      APPPILOT_ADD_STATIC_ENV_ACTION="$ref_env_action"
      return 0
    fi
    validation_status="$?"
    case "$validation_status" in
      "$APPPILOT_ERR_ARGS") log_warn "Some answers are invalid. Check the name, path, and build directory." ;;
      "$APPPILOT_ERR_CONFIG") log_warn "AppPilot could not validate this frontend. Check that the path and build folder exist." ;;
      *) log_warn "AppPilot could not register this static application." ;;
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

cmd_add_static() {
  local name="" path="" build_dir="" environment="production" env_action="ask"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --name)
        [[ -n "${2:-}" ]] || { output_error "--name requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        name="$2"
        shift 2
        ;;
      --path)
        [[ -n "${2:-}" ]] || { output_error "--path requires a project path" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        path="$2"
        shift 2
        ;;
      --build-dir)
        [[ -n "${2:-}" ]] || { output_error "--build-dir requires a relative path" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        build_dir="$2"
        shift 2
        ;;
      --environment)
        [[ -n "${2:-}" ]] || { output_error "--environment requires a value" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        environment="$2"
        shift 2
        ;;
      --env-from-example) env_action="copy"; shift ;;
      --no-env-from-example) env_action="skip"; shift ;;
      *) output_error "Unknown add-static argument: $1" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS" ;;
    esac
  done

  if add_should_prompt; then
    local guided_status=0
    if add_static_collect_guided "$name" "$path" "$build_dir" "$environment" "$env_action"; then
      guided_status=0
    else
      guided_status="$?"
    fi
    case "$guided_status" in
      0) ;;
      11) return "$APPPILOT_OK" ;;
      *) return "$guided_status" ;;
    esac
    name="$APPPILOT_ADD_STATIC_NAME"
    path="$APPPILOT_ADD_STATIC_PATH"
    build_dir="$APPPILOT_ADD_STATIC_BUILD_DIR"
    environment="$APPPILOT_ADD_STATIC_ENVIRONMENT"
    env_action="$APPPILOT_ADD_STATIC_ENV_ACTION"
  fi

  [[ -n "$name" && -n "$path" ]] || {
    output_error "add-static requires --name and --path" "$APPPILOT_ERR_ARGS"
    return "$APPPILOT_ERR_ARGS"
  }
  [[ -n "$build_dir" ]] || build_dir="$(add_static_default_build_dir "$path")"

  registry_validate_new "$name" "static" "$path" "" "" "$build_dir" || {
    local code="$?"
    case "$code" in
      "$APPPILOT_ERR_ARGS") output_error "Invalid static application arguments for '$name'" "$code" ;;
      "$APPPILOT_ERR_CONFIG") output_error "Invalid static application configuration for '$name'" "$code" ;;
      *) output_error "Could not register static application '$name'" "$code" ;;
    esac
    return "$code"
  }

  [[ "$env_action" == "ask" ]] && env_action="skip"
  if [[ "$env_action" == "copy" ]] && ! add_env_example_available "$path"; then
    output_error "Cannot create .env from .env.example for '$name'" "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  fi

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"actions\":[\"register static application $(json_escape "$name")\"],\"buildDir\":$(json_string "$build_dir")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would register static application: $name"
      log_info "Build directory: $build_dir"
      log_info "No changes were made."
    fi
    return "$APPPILOT_OK"
  fi

  lock_acquire "add-static" "$name" || return "$?"
  if [[ "$env_action" == "copy" ]]; then
    env_create_from_example "$path" || {
      local code="$?"
      output_error "Could not create .env from .env.example for '$name'" "$code"
      return "$code"
    }
    [[ "${APPPILOT_JSON:-0}" == "1" ]] || log_check "Created .env from .env.example"
  fi

  registry_add "$name" "static" "$path" "" "" "$environment" "$build_dir" || {
    local code="$?"
    output_error "Could not register static application '$name'" "$code"
    return "$code"
  }

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"registered\":true,\"app\":$(json_string "$name"),\"manager\":\"static\",\"buildDir\":$(json_string "$build_dir")}"
  else
    log_check "Registered $name (static)"
  fi
}
