#!/usr/bin/env bash

config_setup_paths() {
  APPPILOT_CONFIG_HOME="${APPPILOT_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/apppilot}"
  APPPILOT_STATE_HOME="${APPPILOT_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/apppilot}"
  APPPILOT_APPS_DIR="$APPPILOT_CONFIG_HOME/apps"
  APPPILOT_SECRETS_DIR="$APPPILOT_CONFIG_HOME/secrets"
  APPPILOT_LOCKS_DIR="$APPPILOT_STATE_HOME/locks"
  APPPILOT_CONFIG_FILE="$APPPILOT_CONFIG_HOME/apppilot.yml"
  export APPPILOT_CONFIG_HOME APPPILOT_STATE_HOME APPPILOT_APPS_DIR APPPILOT_SECRETS_DIR
  export APPPILOT_LOCKS_DIR APPPILOT_CONFIG_FILE
}

config_init() {
  local actions=()
  local path
  for path in "$APPPILOT_CONFIG_HOME" "$APPPILOT_APPS_DIR" "$APPPILOT_SECRETS_DIR" "$APPPILOT_STATE_HOME" "$APPPILOT_LOCKS_DIR"; do
    [[ -d "$path" ]] || actions+=("create directory $path")
  done
  [[ -f "$APPPILOT_CONFIG_FILE" ]] || actions+=("create config $APPPILOT_CONFIG_FILE")

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    printf '%s\n' "${actions[@]:-}"
    return 0
  fi

  mkdir -p "$APPPILOT_CONFIG_HOME" "$APPPILOT_APPS_DIR" "$APPPILOT_SECRETS_DIR" "$APPPILOT_STATE_HOME" "$APPPILOT_LOCKS_DIR"
  chmod 700 "$APPPILOT_SECRETS_DIR" 2>/dev/null || true
  if [[ ! -f "$APPPILOT_CONFIG_FILE" ]]; then
    local tmp_file
    tmp_file="$(mktemp "$APPPILOT_CONFIG_HOME/apppilot.yml.XXXXXX")"
    {
      printf 'version: 1\n\n'
      printf 'server:\n'
      printf '  name: local\n\n'
      printf 'defaults:\n'
      printf '  output: human\n'
    } >"$tmp_file"
    chmod 600 "$tmp_file" 2>/dev/null || true
    mv "$tmp_file" "$APPPILOT_CONFIG_FILE"
  fi
}

config_exists() {
  [[ -f "$APPPILOT_CONFIG_FILE" && -d "$APPPILOT_APPS_DIR" ]]
}
