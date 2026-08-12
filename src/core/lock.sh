#!/usr/bin/env bash

lock_acquire() {
  local operation="$1"
  local app="${2:-global}"
  mkdir -p "$APPPILOT_LOCKS_DIR"
  APPPILOT_LOCK_FILE="$APPPILOT_LOCKS_DIR/${operation}-${app}.lock"

  if command -v flock >/dev/null 2>&1; then
    exec 9>"$APPPILOT_LOCK_FILE"
    if ! flock -n 9; then
      output_error "Another AppPilot operation is already running: $operation $app" "$APPPILOT_ERR_LOCKED"
      return "$APPPILOT_ERR_LOCKED"
    fi
    printf 'operation: %s\napp: %s\npid: %s\n' "$operation" "$app" "$$" 1>&9
  else
    if ! mkdir "${APPPILOT_LOCK_FILE}.d" 2>/dev/null; then
      output_error "Another AppPilot operation is already running: $operation $app" "$APPPILOT_ERR_LOCKED"
      return "$APPPILOT_ERR_LOCKED"
    fi
    trap 'rm -rf "${APPPILOT_LOCK_FILE}.d"' EXIT
  fi
}
