#!/usr/bin/env bash

env_example_available() {
  local project_path="$1"
  [[ -f "$project_path/.env.example" && ! -L "$project_path/.env.example" && ! -e "$project_path/.env" ]]
}

env_create_from_example() {
  local project_path="$1"
  local source="$project_path/.env.example"
  local dest="$project_path/.env"
  local tmp_file

  [[ -f "$source" && ! -L "$source" ]] || return "$APPPILOT_ERR_CONFIG"
  [[ ! -e "$dest" ]] || return "$APPPILOT_ERR_CONFIG"
  tmp_file="$(mktemp "$project_path/.env.apppilot.XXXXXX")" || return "$APPPILOT_ERR_PERMISSION"
  if ! cp "$source" "$tmp_file"; then
    rm -f "$tmp_file"
    return "$APPPILOT_ERR_PERMISSION"
  fi
  chmod 600 "$tmp_file" 2>/dev/null || true
  if [[ -e "$dest" ]]; then
    rm -f "$tmp_file"
    return "$APPPILOT_ERR_CONFIG"
  fi
  mv "$tmp_file" "$dest" || {
    rm -f "$tmp_file"
    return "$APPPILOT_ERR_PERMISSION"
  }
}
