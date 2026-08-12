#!/usr/bin/env bash

docker_audit_lines() {
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    printf 'info|docker|Docker unavailable; skipping container port audit\n'
    return 0
  fi

  local found=0
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    found=1
    if [[ "$line" == *"0.0.0.0:5432"* || "$line" == *":::5432"* || "$line" == *"0.0.0.0:6379"* || "$line" == *":::6379"* ]]; then
      printf 'warning|docker_ports|Sensitive service appears publicly published: %s\n' "$line"
    else
      printf 'info|docker_ports|Published container port: %s\n' "$line"
    fi
  done < <(docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null)

  [[ "$found" -eq 1 ]] || printf 'ok|docker_ports|No published Docker ports detected\n'
}
