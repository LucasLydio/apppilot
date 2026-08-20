#!/usr/bin/env bash

expose_config_name() {
  local domain="$1"
  printf 'apppilot-%s-%s.conf' "$APP_NAME" "${domain//[^A-Za-z0-9_.-]/_}"
}

expose_config_path() {
  local domain="$1"
  printf '%s/%s' "$APPPILOT_NGINX_AVAILABLE_DIR" "$(expose_config_name "$domain")"
}

expose_enabled_path() {
  local domain="$1"
  printf '%s/%s' "$APPPILOT_NGINX_ENABLED_DIR" "$(expose_config_name "$domain")"
}

expose_json_actions() {
  local first=1 action
  printf '['
  for action in "$@"; do
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    json_string "$action"
  done
  printf ']'
}

expose_default_type() {
  if [[ "$APP_MANAGER" == "static" || -d "$APP_PATH/dist" || -d "$APP_PATH/build" ]]; then
    printf 'static'
  else
    printf 'proxy'
  fi
}

expose_default_build_dir() {
  local candidate
  if [[ -n "$APP_BUILD_DIR" ]]; then
    printf '%s' "$APP_BUILD_DIR"
    return 0
  fi
  for candidate in dist build public; do
    if [[ -d "$APP_PATH/$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  printf 'dist'
}

expose_validate_domain() {
  local domain="${1:-}"
  [[ "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,252}[A-Za-z0-9]$ ]]
}

expose_render_config() {
  local domain="$1"
  local type="$2"
  local build_dir="$3"
  local port="$4"
  local listen_port="$5"

  printf 'server {\n'
  printf '    listen %s;\n' "$listen_port"
  printf '    listen [::]:%s;\n' "$listen_port"
  printf '    server_name %s;\n\n' "$domain"
  if [[ "$type" == "static" ]]; then
    printf '    root %s/%s;\n' "$APP_PATH" "$build_dir"
    printf '    index index.html;\n\n'
    printf '    location / {\n'
    printf "        try_files \$uri \$uri/ /index.html;\n"
    printf '    }\n'
  else
    printf '    location / {\n'
    printf '        proxy_pass http://127.0.0.1:%s;\n' "$port"
    printf '        proxy_http_version 1.1;\n'
    printf "        proxy_set_header Host \$host;\n"
    printf "        proxy_set_header X-Real-IP \$remote_addr;\n"
    printf "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n"
    printf "        proxy_set_header X-Forwarded-Proto \$scheme;\n"
    printf "        proxy_set_header Upgrade \$http_upgrade;\n"
    printf '        proxy_set_header Connection "upgrade";\n'
    printf '    }\n'
  fi
  printf '}\n'
}

expose_install_file() {
  local source="$1"
  local target="$2"
  if [[ -w "$(dirname "$target")" ]]; then
    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
  else
    sudo mkdir -p "$(dirname "$target")"
    sudo cp "$source" "$target"
  fi
}

expose_enable_site() {
  local config="$1"
  local enabled="$2"
  if [[ -w "$(dirname "$enabled")" ]]; then
    mkdir -p "$(dirname "$enabled")"
    ln -sfn "$config" "$enabled"
  else
    sudo mkdir -p "$(dirname "$enabled")"
    sudo ln -sfn "$config" "$enabled"
  fi
}

expose_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

expose_nginx_pid_present() {
  local pid_file="/run/nginx.pid"
  local pid=""
  [[ -s "$pid_file" ]] || return 1
  pid="$(tr -d '[:space:]' < "$pid_file" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]]
}

expose_nginx_check_reload() {
  expose_privileged nginx -t || return "$?"

  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    expose_privileged systemctl reload nginx && return 0
    expose_privileged systemctl restart nginx && return 0
  fi

  if command -v service >/dev/null 2>&1; then
    expose_privileged service nginx reload && return 0
    expose_privileged service nginx restart && return 0
  fi

  if expose_nginx_pid_present; then
    expose_privileged nginx -s reload && return 0
  fi

  expose_privileged nginx
}

expose_nginx_failure_hint() {
  [[ "${APPPILOT_JSON:-0}" == "1" || "${APPPILOT_QUIET:-0}" == "1" ]] && return 0
  log_warn "Nginx config is valid, but Nginx could not reload or start."
  log_info "Check the service log:"
  log_info "  sudo journalctl -u nginx.service -n 50 --no-pager"
  log_info "Check whether another process is using ports 80 or 443:"
  log_info "  sudo ss -ltnp | grep -E ':80|:443'"
}

expose_run_certbot() {
  local domain="$1"
  local email="$2"
  if [[ -n "$email" ]]; then
    expose_privileged certbot --nginx -d "$domain" --email "$email" --agree-tos --non-interactive
  else
    expose_privileged certbot --nginx -d "$domain" --register-unsafely-without-email --agree-tos --non-interactive
  fi
}

cmd_expose() {
  local app="" domain="" type="" build_dir="" port="" listen_port="80" ssl=0 email="" yes=0
  local config_path="" enabled_path="" tmp_config=""
  local nginx_status=0
  local -a actions=()

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --domain)
        [[ -n "${2:-}" ]] || { output_error "--domain requires a domain" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        domain="$2"
        shift 2
        ;;
      --type)
        [[ -n "${2:-}" ]] || { output_error "--type requires static or proxy" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        type="$2"
        shift 2
        ;;
      --build-dir)
        [[ -n "${2:-}" ]] || { output_error "--build-dir requires a relative path" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        build_dir="$2"
        shift 2
        ;;
      --port)
        [[ -n "${2:-}" ]] || { output_error "--port requires a port" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        port="$2"
        shift 2
        ;;
      --listen-port)
        [[ -n "${2:-}" ]] || { output_error "--listen-port requires a port" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        listen_port="$2"
        shift 2
        ;;
      --ssl) ssl=1; shift ;;
      --email)
        [[ -n "${2:-}" ]] || { output_error "--email requires an email address" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
        email="$2"
        shift 2
        ;;
      --yes|-y) yes=1; shift ;;
      --dry-run) APPPILOT_DRY_RUN=1; export APPPILOT_DRY_RUN; shift ;;
      --json) APPPILOT_JSON=1; export APPPILOT_JSON; shift ;;
      --quiet) APPPILOT_QUIET=1; export APPPILOT_QUIET; shift ;;
      --non-interactive) APPPILOT_NON_INTERACTIVE=1; export APPPILOT_NON_INTERACTIVE; shift ;;
      *) if [[ -z "$app" ]]; then app="$1"; shift; else output_error "expose accepts one application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; fi ;;
    esac
  done

  [[ -n "$app" ]] || { output_error "expose requires an application name" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ -n "$domain" ]] || { output_error "expose requires --domain" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  expose_validate_domain "$domain" || { output_error "Invalid domain: $domain" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ "$listen_port" =~ ^[0-9]+$ && "$listen_port" -gt 0 && "$listen_port" -le 65535 ]] || { output_error "--listen-port must be 1-65535" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ "$ssl" != "1" || "$listen_port" == "80" ]] || { output_error "expose --ssl requires --listen-port 80 for Certbot HTTP validation" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }

  registry_load "$app" || {
    local code="$?"
    output_error "Application not found or invalid: $app" "$code"
    return "$code"
  }

  [[ -n "$type" ]] || type="$(expose_default_type)"
  [[ "$type" == "static" || "$type" == "proxy" ]] || { output_error "--type must be static or proxy" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  [[ -n "$build_dir" ]] || build_dir="$(expose_default_build_dir)"

  if [[ "$type" == "static" ]]; then
    validator_relative_path_safe "$build_dir" || { output_error "Build directory must be relative and safe" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
    [[ -d "$APP_PATH/$build_dir" ]] || { output_error "Build directory does not exist: $APP_PATH/$build_dir" "$APPPILOT_ERR_CONFIG"; return "$APPPILOT_ERR_CONFIG"; }
  else
    [[ "$port" =~ ^[0-9]+$ && "$port" -gt 0 && "$port" -le 65535 ]] || { output_error "Proxy exposure requires --port 1-65535" "$APPPILOT_ERR_ARGS"; return "$APPPILOT_ERR_ARGS"; }
  fi

  config_path="$(expose_config_path "$domain")"
  enabled_path="$(expose_enabled_path "$domain")"
  actions+=("write Nginx config $config_path")
  actions+=("enable site $enabled_path")
  actions+=("test and reload or start Nginx")
  [[ "$ssl" == "1" ]] && actions+=("issue SSL certificate with Certbot for $domain")

  if [[ "${APPPILOT_DRY_RUN:-0}" == "1" ]]; then
    if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
      output_success_json "{\"app\":$(json_string "$APP_NAME"),\"domain\":$(json_string "$domain"),\"type\":$(json_string "$type"),\"buildDir\":$(json_string "$build_dir"),\"port\":$(json_string "$port"),\"listenPort\":$(json_string "$listen_port"),\"ssl\":$(json_bool "$ssl"),\"configPath\":$(json_string "$config_path"),\"actions\":$(expose_json_actions "${actions[@]}")}" "[]" "true"
    else
      output_dry_run_header
      log_info "Would expose: $APP_NAME"
      log_info "Domain: $domain"
      log_info "Type: $type"
      log_info "Listen port: $listen_port"
      [[ "$type" == "static" ]] && log_info "Build directory: $build_dir"
      [[ "$type" == "proxy" ]] && log_info "Target: http://127.0.0.1:$port"
      local action
      for action in "${actions[@]}"; do
        log_info "- $action"
      done
      printf '\n'
      expose_render_config "$domain" "$type" "$build_dir" "$port" "$listen_port"
      printf '\nNo changes were made.\n'
    fi
    return "$APPPILOT_OK"
  fi

  [[ "$yes" == "1" || "${APPPILOT_NON_INTERACTIVE:-0}" != "1" ]] || {
    output_error "expose requires --yes in non-interactive mode" "$APPPILOT_ERR_ARGS"
    return "$APPPILOT_ERR_ARGS"
  }
  command -v nginx >/dev/null 2>&1 || { output_error "Nginx is required. Run: apppilot adapters install nginx" "$APPPILOT_ERR_MISSING_DEP"; return "$APPPILOT_ERR_MISSING_DEP"; }
  if [[ "$ssl" == "1" ]]; then
    command -v certbot >/dev/null 2>&1 || { output_error "Certbot is required. Run: apppilot adapters install certbot" "$APPPILOT_ERR_MISSING_DEP"; return "$APPPILOT_ERR_MISSING_DEP"; }
  fi

  lock_acquire "expose" "$APP_NAME" || return "$?"
  tmp_config="$(mktemp)"
  expose_render_config "$domain" "$type" "$build_dir" "$port" "$listen_port" >"$tmp_config"
  expose_install_file "$tmp_config" "$config_path"
  rm -f "$tmp_config"
  expose_enable_site "$config_path" "$enabled_path"
  expose_nginx_check_reload
  nginx_status="$?"
  if [[ "$nginx_status" -ne 0 ]]; then
    expose_nginx_failure_hint
    output_error "Nginx could not reload or start after writing the site config" "$APPPILOT_ERR_CONFIG"
    return "$APPPILOT_ERR_CONFIG"
  fi
  [[ "$ssl" == "1" ]] && expose_run_certbot "$domain" "$email"

  if [[ "${APPPILOT_JSON:-0}" == "1" ]]; then
    output_success_json "{\"app\":$(json_string "$APP_NAME"),\"domain\":$(json_string "$domain"),\"type\":$(json_string "$type"),\"listenPort\":$(json_string "$listen_port"),\"configPath\":$(json_string "$config_path"),\"exposed\":true}"
  else
    log_check "Nginx exposure configured"
    log_info "Domain: $domain"
    log_info "Listen port: $listen_port"
    log_info "Config: $config_path"
  fi
}
