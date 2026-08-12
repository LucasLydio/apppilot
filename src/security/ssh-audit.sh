#!/usr/bin/env bash

ssh_audit_lines() {
  local config="/etc/ssh/sshd_config"
  if [[ ! -r "$config" ]]; then
    printf 'warning|ssh_config|SSH configuration is not readable\n'
    return 0
  fi

  local root_login password_auth pubkey_auth port
  root_login="$(awk 'tolower($1)=="permitrootlogin" {print tolower($2); found=1} END {if (!found) print "default"}' "$config")"
  password_auth="$(awk 'tolower($1)=="passwordauthentication" {print tolower($2); found=1} END {if (!found) print "default"}' "$config")"
  pubkey_auth="$(awk 'tolower($1)=="pubkeyauthentication" {print tolower($2); found=1} END {if (!found) print "default"}' "$config")"
  port="$(awk 'tolower($1)=="port" {print $2; found=1} END {if (!found) print "22"}' "$config")"

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

  if [[ "$pubkey_auth" == "yes" || "$pubkey_auth" == "default" ]]; then
    printf 'ok|ssh_pubkey_auth|SSH public-key authentication appears available (%s)\n' "$pubkey_auth"
  else
    printf 'warning|ssh_pubkey_auth|Review SSH public-key authentication setting (%s)\n' "$pubkey_auth"
  fi

  if command -v systemctl >/dev/null 2>&1 && systemctl is-active ssh >/dev/null 2>&1; then
    printf 'ok|ssh_service|SSH service is active\n'
  elif command -v systemctl >/dev/null 2>&1 && systemctl is-active sshd >/dev/null 2>&1; then
    printf 'ok|ssh_service|SSHD service is active\n'
  else
    printf 'info|ssh_service|SSH service state unavailable or inactive\n'
  fi

  printf 'info|ssh_port|SSH configured port: %s\n' "$port"
}
