#!/usr/bin/env bash

ssh_audit_lines() {
  local config="/etc/ssh/sshd_config"
  if [[ ! -r "$config" ]]; then
    printf 'warning|ssh_config|SSH configuration is not readable\n'
    return 0
  fi

  local root_login password_auth
  root_login="$(awk 'tolower($1)=="permitrootlogin" {print tolower($2); found=1} END {if (!found) print "default"}' "$config")"
  password_auth="$(awk 'tolower($1)=="passwordauthentication" {print tolower($2); found=1} END {if (!found) print "default"}' "$config")"

  if [[ "$root_login" == "no" ]]; then
    printf 'ok|ssh_root_login|SSH root login disabled\n'
  else
    printf 'warning|ssh_root_login|Review SSH root login setting (%s)\n' "$root_login"
  fi

  if [[ "$password_auth" == "no" ]]; then
    printf 'ok|ssh_password_auth|SSH password authentication disabled\n'
  else
    printf 'warning|ssh_password_auth|Review SSH password authentication setting (%s)\n' "$password_auth"
  fi
}
