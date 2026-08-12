#!/usr/bin/env bash

permissions_audit_lines() {
  if [[ ! -d "$APPPILOT_SECRETS_DIR" ]]; then
    printf 'warning|secrets_dir|AppPilot secrets directory does not exist\n'
    return 0
  fi

  local mode
  mode="$(stat -c '%a' "$APPPILOT_SECRETS_DIR" 2>/dev/null || stat -f '%Lp' "$APPPILOT_SECRETS_DIR" 2>/dev/null || printf 'unknown')"
  if [[ "$mode" == "700" ]]; then
    printf 'ok|secrets_dir|AppPilot secrets directory permissions are restricted\n'
  else
    printf 'warning|secrets_dir|Review AppPilot secrets directory permissions (%s)\n' "$mode"
  fi

  local file file_mode
  while IFS= read -r file; do
    file_mode="$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null || printf 'unknown')"
    if [[ "$file_mode" == "600" ]]; then
      printf 'ok|secret_file|Secret file permissions are restricted: %s\n' "$file"
    else
      printf 'warning|secret_file|Review secret file permissions (%s): %s\n' "$file_mode" "$file"
    fi
  done < <(find "$APPPILOT_SECRETS_DIR" -type f 2>/dev/null)
}
