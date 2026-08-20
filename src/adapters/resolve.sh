#!/usr/bin/env bash

adapter_validate() {
  case "$APP_MANAGER" in
    pm2) pm2_validate ;;
    compose) compose_validate ;;
    static) return "$APPPILOT_OK" ;;
    *) return "$APPPILOT_ERR_UNSUPPORTED" ;;
  esac
}

adapter_start() {
  case "$APP_MANAGER" in
    pm2) pm2_start ;;
    compose) compose_start ;;
    *) return "$APPPILOT_ERR_UNSUPPORTED" ;;
  esac
}

adapter_stop() {
  case "$APP_MANAGER" in
    pm2) pm2_stop ;;
    compose) compose_stop ;;
    *) return "$APPPILOT_ERR_UNSUPPORTED" ;;
  esac
}

adapter_restart() {
  case "$APP_MANAGER" in
    pm2) pm2_restart ;;
    compose) compose_restart ;;
    *) return "$APPPILOT_ERR_UNSUPPORTED" ;;
  esac
}

adapter_status() {
  case "$APP_MANAGER" in
    pm2) pm2_status_text ;;
    compose) compose_status ;;
    static) printf 'static\n' ;;
    *) return "$APPPILOT_ERR_UNSUPPORTED" ;;
  esac
}

adapter_status_details() {
  case "$APP_MANAGER" in
    pm2) pm2_status_details ;;
    compose) compose_status_details ;;
    static)
      printf 'runtimeName\t%s\n' "$APP_NAME"
      printf 'status\tstatic\n'
      printf 'services\tnginx\n'
      printf 'buildDir\t%s\n' "$APP_BUILD_DIR"
      ;;
    *) return "$APPPILOT_ERR_UNSUPPORTED" ;;
  esac
}

adapter_logs() {
  case "$APP_MANAGER" in
    pm2) pm2_logs ;;
    compose) compose_logs ;;
    *) return "$APPPILOT_ERR_UNSUPPORTED" ;;
  esac
}
