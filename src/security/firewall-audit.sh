#!/usr/bin/env bash

firewall_audit_lines() {
  if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -qi 'Status: active'; then
      printf 'ok|ufw|UFW firewall is active\n'
    else
      printf 'warning|ufw|UFW firewall is installed but not active\n'
    fi
  elif command -v firewall-cmd >/dev/null 2>&1; then
    if firewall-cmd --state >/dev/null 2>&1; then
      printf 'ok|firewalld|firewalld is active\n'
    else
      printf 'warning|firewalld|firewalld is installed but not active\n'
    fi
  else
    printf 'warning|firewall|No supported firewall tool detected\n'
  fi
  local port
  while IFS= read -r port; do
    [[ -n "$port" ]] || continue
    printf 'info|listening_port|Listening TCP port detected: %s\n' "$port"
  done < <(ports_listening_tcp)
}
