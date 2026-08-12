#!/usr/bin/env bash

validator_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,62}$ ]]
}

validator_manager() {
  local manager="${1:-}"
  [[ "$manager" == "pm2" || "$manager" == "compose" ]]
}

validator_path_safe() {
  local path="${1:-}"
  [[ "$path" == /* ]] || return 1
  [[ "$path" != *".."* ]]
}

validator_required() {
  [[ -n "${1:-}" ]]
}
