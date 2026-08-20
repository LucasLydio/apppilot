#!/usr/bin/env bash

registry_ensure() {
  mkdir -p "$APPPILOT_APPS_DIR"
}

registry_load() {
  local name="$1"
  validator_name "$name" || return "$APPPILOT_ERR_ARGS"
  local file
  file="$(app_config_file_for "$name")"
  [[ ! -L "$file" ]] || return "$APPPILOT_ERR_CONFIG"
  app_config_load_file "$file" || return "$APPPILOT_ERR_APP_NOT_FOUND"
  [[ "$APP_NAME" == "$name" ]] || return "$APPPILOT_ERR_CONFIG"
  app_config_validate_loaded
}

registry_add() {
  local name="$1"
  local manager="$2"
  local path="$3"
  local entrypoint="${4:-}"
  local compose_file="${5:-}"
  local environment="${6:-production}"
  local build_dir="${7:-}"
  local file

  registry_validate_new "$name" "$manager" "$path" "$entrypoint" "$compose_file" "$build_dir" || return "$?"
  file="$(app_config_file_for "$name")"
  registry_ensure
  local tmp_file
  tmp_file="$(mktemp "$APPPILOT_APPS_DIR/$name.yml.XXXXXX")"
  {
    printf 'name: %s\n' "$name"
    printf 'manager: %s\n' "$manager"
    printf 'path: %s\n' "$path"
    if [[ "$manager" == "pm2" ]]; then
      printf 'entrypoint: %s\n' "$entrypoint"
    elif [[ "$manager" == "compose" ]]; then
      printf 'compose_file: %s\n' "$compose_file"
    else
      printf 'build_dir: %s\n' "$build_dir"
    fi
    printf 'environment: %s\n' "$environment"
  } >"$tmp_file"
  chmod 600 "$tmp_file" 2>/dev/null || true
  mv "$tmp_file" "$file"
}

registry_validate_new() {
  local name="$1"
  local manager="$2"
  local path="$3"
  local entrypoint="${4:-}"
  local compose_file="${5:-}"
  local build_dir="${6:-}"
  local file

  validator_name "$name" || return "$APPPILOT_ERR_ARGS"
  validator_registry_manager "$manager" || return "$APPPILOT_ERR_ARGS"
  validator_path_safe "$path" || return "$APPPILOT_ERR_ARGS"
  [[ -d "$path" ]] || return "$APPPILOT_ERR_CONFIG"
  file="$(app_config_file_for "$name")"
  [[ ! -e "$file" ]] || return "$APPPILOT_ERR_CONFIG"

  case "$manager" in
    pm2)
      validator_relative_path_safe "$entrypoint" || return "$APPPILOT_ERR_CONFIG"
      [[ -f "$path/$entrypoint" && ! -L "$path/$entrypoint" ]] || return "$APPPILOT_ERR_CONFIG"
      ;;
    compose)
      validator_relative_path_safe "$compose_file" || return "$APPPILOT_ERR_CONFIG"
      [[ -f "$path/$compose_file" && ! -L "$path/$compose_file" ]] || return "$APPPILOT_ERR_CONFIG"
      ;;
    static)
      validator_relative_path_safe "$build_dir" || return "$APPPILOT_ERR_CONFIG"
      [[ -d "$path/$build_dir" && ! -L "$path/$build_dir" ]] || return "$APPPILOT_ERR_CONFIG"
      ;;
  esac
}

registry_remove() {
  local name="$1"
  validator_name "$name" || return "$APPPILOT_ERR_ARGS"
  local file
  file="$(app_config_file_for "$name")"
  [[ -f "$file" ]] || return "$APPPILOT_ERR_APP_NOT_FOUND"
  rm -f "$file"
}

registry_names() {
  [[ -d "$APPPILOT_APPS_DIR" ]] || return 0
  local file
  for file in "$APPPILOT_APPS_DIR"/*.yml; do
    [[ -e "$file" ]] || continue
    basename "$file" .yml
  done | sort
}

registry_json_array() {
  local first=1
  local name file
  printf '['
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    file="$(app_config_file_for "$name")"
    app_config_load_file "$file" || continue
    if [[ "$first" -eq 0 ]]; then printf ','; fi
    first=0
    app_config_to_json
  done < <(registry_names)
  printf ']'
}
