#!/usr/bin/env bash

host_detect() {
  HOST_IS_LINUX=false
  HOST_DISTRO_ID="unsupported"
  HOST_DISTRO_NAME="unsupported"
  HOST_DISTRO_VERSION=""
  HOST_ARCH="$(uname -m 2>/dev/null || printf 'unknown')"
  HOST_BASH_VERSION="${BASH_VERSION:-unknown}"
  HOST_HOSTNAME="$(hostname 2>/dev/null || printf 'unknown')"
  HOST_PACKAGE_MANAGER="$(package_manager_detect)"

  if [[ "$(uname -s 2>/dev/null || true)" == "Linux" ]]; then
    HOST_IS_LINUX=true
  fi

  if [[ -r /etc/os-release ]]; then
    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" == *=* ]] || continue
      key="${line%%=*}"
      value="${line#*=}"
      value="${value%\"}"
      value="${value#\"}"
      case "$key" in
        ID) HOST_DISTRO_ID="$value" ;;
        NAME) HOST_DISTRO_NAME="$value" ;;
        VERSION_ID) HOST_DISTRO_VERSION="$value" ;;
      esac
    done </etc/os-release
  fi
}

host_supported_distro() {
  [[ "$HOST_DISTRO_ID" == "ubuntu" || "$HOST_DISTRO_ID" == "debian" ]]
}

host_json() {
  host_detect
  printf '{"linux":%s,"distro":%s,"version":%s,"architecture":%s,"bashVersion":%s,"hostname":%s,"packageManager":%s,"supported":%s}' \
    "$(json_bool "$HOST_IS_LINUX")" "$(json_string "$HOST_DISTRO_NAME")" "$(json_string "$HOST_DISTRO_VERSION")" \
    "$(json_string "$HOST_ARCH")" "$(json_string "$HOST_BASH_VERSION")" "$(json_string "$HOST_HOSTNAME")" \
    "$(json_string "$HOST_PACKAGE_MANAGER")" "$(json_bool "$(host_supported_distro && printf true || printf false)")"
}
