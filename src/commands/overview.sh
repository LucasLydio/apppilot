#!/usr/bin/env bash

overview_app_count() {
  local count=0
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] && count=$((count + 1))
  done < <(registry_names)
  printf '%s' "$count"
}

cmd_overview() {
  [[ "$#" -eq 0 ]] || { output_error "overview does not accept arguments" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  host_detect

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"host\":$(host_json),\"resources\":$(resources_json),\"appCount\":$(overview_app_count),\"adapters\":$(adapters_json)}"
    return "$APPPILOT_OK"
  fi

  ui_banner
  ui_section "Host"
  ui_kv "System" "$HOST_DISTRO_NAME ${HOST_DISTRO_VERSION:-}"
  ui_kv "Architecture" "$HOST_ARCH"
  ui_kv "Package manager" "$HOST_PACKAGE_MANAGER"
  ui_kv "Uptime" "$(resource_uptime_summary)"

  ui_section "Resources"
  ui_kv "CPU" "$(resource_cpu_count) cores"
  ui_kv "Memory" "$(resource_memory_summary)"
  ui_kv "Disk" "$(resource_disk_summary)"

  ui_section "AppPilot"
  if config_exists; then
    ui_status_line ok "Configuration" "$APPPILOT_CONFIG_HOME"
  else
    ui_status_line warning "Configuration" "not initialized"
  fi
  ui_kv "Applications" "$(overview_app_count) registered"

  ui_section "Adapters"
  ui_status_line "$(adapter_status_pm2)" "PM2" "$(adapter_status_pm2)"
  ui_status_line "$(adapter_status_compose)" "Docker Compose" "$(adapter_status_compose)"

  ui_section "Next Commands"
  printf '  apppilot doctor\n'
  printf '  apppilot validate\n'
  printf '  apppilot security audit\n'
}
