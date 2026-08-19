#!/usr/bin/env bash

adapter_status_pm2() {
  command -v pm2 >/dev/null 2>&1 && printf 'installed' || printf 'missing'
}

adapter_status_git() {
  command -v git >/dev/null 2>&1 && printf 'installed' || printf 'missing'
}

adapter_status_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    printf 'missing'
  elif ! docker compose version >/dev/null 2>&1; then
    printf 'partial'
  else
    printf 'installed'
  fi
}

adapter_node_lts_label() {
  command -v node >/dev/null 2>&1 || return 1
  node -p "process.release && process.release.lts ? process.release.lts : ''" 2>/dev/null
}

adapter_node_major() {
  command -v node >/dev/null 2>&1 || return 1
  node -p "Number(process.versions.node.split('.')[0])" 2>/dev/null
}

adapter_require_supported_apt_host() {
  host_detect
  [[ "$HOST_IS_LINUX" == "true" ]] || return "$APPPILOT_ERR_UNSUPPORTED"
  [[ "$(package_manager_detect)" == "apt" ]] || return "$APPPILOT_ERR_UNSUPPORTED"
  [[ "$HOST_DISTRO_ID" == "ubuntu" || "$HOST_DISTRO_ID" == "debian" ]] || return "$APPPILOT_ERR_UNSUPPORTED"
}

adapter_os_codename() {
  [[ -r /etc/os-release ]] || return 1
  awk -F= '
    $1 == "UBUNTU_CODENAME" {gsub(/"/, "", $2); print $2; found=1}
    $1 == "VERSION_CODENAME" && !found {gsub(/"/, "", $2); value=$2}
    END {if (!found && value != "") print value}
  ' /etc/os-release
}

adapters_json() {
  local git_status pm2_status compose_status
  git_status="$(adapter_status_git)"
  pm2_status="$(adapter_status_pm2)"
  compose_status="$(adapter_status_compose)"
  printf '[{"name":"git","type":"source-control","builtIn":true,"status":%s,"requiredCommands":["git"]},{"name":"pm2","type":"process-manager","builtIn":true,"status":%s,"requiredCommands":["pm2"]},{"name":"compose","type":"container-orchestrator","builtIn":true,"status":%s,"requiredCommands":["docker","docker compose"]}]' \
    "$(json_string "$git_status")" "$(json_string "$pm2_status")" "$(json_string "$compose_status")"
}

adapters_missing_targets() {
  [[ "$(adapter_status_git)" == "installed" ]] || printf 'git\n'
  [[ "$(adapter_status_pm2)" == "installed" ]] || printf 'pm2\n'
  [[ "$(adapter_status_compose)" == "installed" ]] || printf 'compose\n'
}

adapter_install_plan() {
  local target="$1"
  case "$target" in
    git)
      command -v git >/dev/null 2>&1 || printf 'Install Git through apt\n'
      printf 'Verify git is available on PATH\n'
      ;;
    pm2)
      command -v node >/dev/null 2>&1 || printf 'Install Node.js LTS from NodeSource apt repository\n'
      command -v npm >/dev/null 2>&1 || printf 'Install npm through Node.js LTS package\n'
      command -v pm2 >/dev/null 2>&1 || printf 'Install PM2 globally with npm\n'
      printf 'Verify Node.js reports an LTS release\n'
      ;;
    compose)
      command -v docker >/dev/null 2>&1 || printf 'Install Docker Engine from Docker official apt repository\n'
      docker compose version >/dev/null 2>&1 || printf 'Install Docker Compose plugin\n'
      printf 'Verify Docker and Docker Compose versions\n'
      ;;
  esac
}

adapter_write_nodesource_source() {
  local node_major="${APPPILOT_NODE_LTS_MAJOR:-24}"
  local arch
  arch="$(dpkg --print-architecture)"
  {
    printf 'Types: deb\n'
    printf 'URIs: https://deb.nodesource.com/node_%s.x\n' "$node_major"
    printf 'Suites: nodistro\n'
    printf 'Components: main\n'
    printf 'Architectures: %s\n' "$arch"
    printf 'Signed-By: /usr/share/keyrings/nodesource.gpg\n'
  } | sudo tee /etc/apt/sources.list.d/nodesource.sources >/dev/null
  {
    printf 'Package: nodejs\n'
    printf 'Pin: origin deb.nodesource.com\n'
    printf 'Pin-Priority: 600\n'
  } | sudo tee /etc/apt/preferences.d/nodejs >/dev/null
}

adapter_install_node_lts() {
  local node_major="${APPPILOT_NODE_LTS_MAJOR:-24}"
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
  sudo install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | sudo gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
  sudo chmod 644 /usr/share/keyrings/nodesource.gpg
  adapter_write_nodesource_source
  sudo apt-get update
  sudo apt-get install -y nodejs
  [[ "$(adapter_node_major || printf '0')" -ge "$node_major" ]]
}

adapter_confirm_install() {
  local target="$1"
  local yes="$2"
  local answer
  [[ "$yes" == "1" ]] && return 0
  read -r -p "Install adapter dependencies for $target? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

adapter_install_pm2() {
  adapter_require_supported_apt_host || return "$?"
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1 || [[ "$(adapter_node_major || printf '0')" -lt 18 ]]; then
    adapter_install_node_lts || return "$APPPILOT_ERR_MISSING_DEP"
  fi

  local lts major
  lts="$(adapter_node_lts_label || true)"
  major="$(adapter_node_major || printf '0')"
  if [[ -z "$lts" || "$major" -lt 18 ]]; then
    output_error "Node.js LTS 18+ is required before installing PM2." "$APPPILOT_ERR_HEALTH"
    return "$APPPILOT_ERR_HEALTH"
  fi

  if ! command -v pm2 >/dev/null 2>&1; then
    sudo npm install -g pm2
  fi
  command -v pm2 >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
}

adapter_install_git() {
  adapter_require_supported_apt_host || return "$?"
  if ! command -v git >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y git
  fi
  command -v git >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
}

adapter_write_docker_source() {
  local distro="$1"
  local codename="$2"
  local arch
  arch="$(dpkg --print-architecture)"
  {
    printf 'Types: deb\n'
    printf 'URIs: https://download.docker.com/linux/%s\n' "$distro"
    printf 'Suites: %s\n' "$codename"
    printf 'Components: stable\n'
    printf 'Architectures: %s\n' "$arch"
    printf 'Signed-By: /etc/apt/keyrings/docker.asc\n'
  } | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
}

adapter_install_compose() {
  adapter_require_supported_apt_host || return "$?"
  local codename
  codename="$(adapter_os_codename)"
  [[ -n "$codename" ]] || return "$APPPILOT_ERR_CONFIG"

  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL "https://download.docker.com/linux/$HOST_DISTRO_ID/gpg" -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  adapter_write_docker_source "$HOST_DISTRO_ID" "$codename"
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  command -v docker >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
  docker compose version >/dev/null 2>&1 || return "$APPPILOT_ERR_MISSING_DEP"
}

adapter_install_one() {
  local target="$1"
  case "$target" in
    git) adapter_install_git ;;
    pm2) adapter_install_pm2 ;;
    compose) adapter_install_compose ;;
    *) return "$APPPILOT_ERR_ARGS" ;;
  esac
}

adapters_install_json_plan() {
  local target first=1
  local action
  printf '['
  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    while IFS= read -r action; do
      [[ -n "$action" ]] || continue
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      printf '{"adapter":%s,"action":%s}' "$(json_string "$target")" "$(json_string "$action")"
    done < <(adapter_install_plan "$target")
  done
  printf ']'
}

adapter_git_update_status() {
  command -v git >/dev/null 2>&1 || { printf 'git not installed'; return 0; }
  command -v apt >/dev/null 2>&1 || { printf 'apt unavailable'; return 0; }
  if apt list --upgradable 2>/dev/null | grep -Eq '^git/'; then
    printf 'update available through apt'
  else
    printf 'no apt update detected'
  fi
}

adapter_pm2_update_status() {
  command -v npm >/dev/null 2>&1 || { printf 'npm unavailable'; return 0; }
  command -v pm2 >/dev/null 2>&1 || { printf 'pm2 not installed'; return 0; }
  if npm outdated -g pm2 --depth=0 >/dev/null 2>&1; then
    printf 'up to date'
  else
    printf 'update may be available; run npm outdated -g pm2 --depth=0'
  fi
}

adapter_compose_update_status() {
  command -v apt >/dev/null 2>&1 || { printf 'apt unavailable'; return 0; }
  if apt list --upgradable 2>/dev/null | grep -Eq '^(docker-ce|docker-ce-cli|docker-compose-plugin|docker-buildx-plugin|containerd.io)/'; then
    printf 'update available through apt'
  else
    printf 'no apt update detected'
  fi
}
