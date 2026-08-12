#!/usr/bin/env bash

permissions_audit_lines() {
  local config_mode state_mode lock_mode
  if [[ -d "$APPPILOT_CONFIG_HOME" ]]; then
    config_mode="$(stat -c '%a' "$APPPILOT_CONFIG_HOME" 2>/dev/null || stat -f '%Lp' "$APPPILOT_CONFIG_HOME" 2>/dev/null || printf 'unknown')"
    case "${config_mode: -1}" in
      2|3|6|7) printf 'warning|config_dir|Review AppPilot config directory permissions (%s)\n' "$config_mode" ;;
      *) printf 'ok|config_dir|AppPilot config directory is not world-writable\n' ;;
    esac
  else
    printf 'warning|config_dir|AppPilot config directory does not exist\n'
  fi

  if [[ -d "$APPPILOT_STATE_HOME" ]]; then
    state_mode="$(stat -c '%a' "$APPPILOT_STATE_HOME" 2>/dev/null || stat -f '%Lp' "$APPPILOT_STATE_HOME" 2>/dev/null || printf 'unknown')"
    case "${state_mode: -1}" in
      2|3|6|7) printf 'warning|state_dir|Review AppPilot state directory permissions (%s)\n' "$state_mode" ;;
      *) printf 'ok|state_dir|AppPilot state directory is not world-writable\n' ;;
    esac
  else
    printf 'warning|state_dir|AppPilot state directory does not exist\n'
  fi

  if [[ -d "$APPPILOT_LOCKS_DIR" ]]; then
    lock_mode="$(stat -c '%a' "$APPPILOT_LOCKS_DIR" 2>/dev/null || stat -f '%Lp' "$APPPILOT_LOCKS_DIR" 2>/dev/null || printf 'unknown')"
    case "${lock_mode: -1}" in
      2|3|6|7) printf 'warning|locks_dir|Review AppPilot lock directory permissions (%s)\n' "$lock_mode" ;;
      *) printf 'ok|locks_dir|AppPilot lock directory is not world-writable\n' ;;
    esac
  fi

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
