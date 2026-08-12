#!/usr/bin/env bash

ports_listening_tcp() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltnH 2>/dev/null | awk '{print $4}' | sed 's/.*://g' | sort -n | uniq
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk 'NR>2 {print $4}' | sed 's/.*://g' | sort -n | uniq
  else
    return 0
  fi
}

ports_json_array() {
  local first=1
  local port
  printf '['
  while IFS= read -r port; do
    [[ -n "$port" ]] || continue
    if [[ "$first" -eq 0 ]]; then printf ','; fi
    first=0
    json_string "$port"
  done < <(ports_listening_tcp)
  printf ']'
}
