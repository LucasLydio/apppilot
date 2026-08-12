#!/usr/bin/env bash

resource_cpu_count() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  else
    getconf _NPROCESSORS_ONLN 2>/dev/null || printf 'unknown'
  fi
}

resource_memory_summary() {
  if command -v free >/dev/null 2>&1; then
    free -m | awk '/^Mem:/ {printf "%s/%s MB used", $3, $2}'
  else
    printf 'unknown'
  fi
}

resource_disk_summary() {
  df -hP / 2>/dev/null | awk 'NR==2 {printf "%s used of %s (%s)", $(NF-3), $(NF-4), $(NF-1)}' || printf 'unknown'
}

resource_uptime_summary() {
  uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'unknown'
}

resources_json() {
  printf '{"cpuCount":%s,"memory":%s,"disk":%s,"uptime":%s}' \
    "$(json_string "$(resource_cpu_count)")" "$(json_string "$(resource_memory_summary)")" \
    "$(json_string "$(resource_disk_summary)")" "$(json_string "$(resource_uptime_summary)")"
}
