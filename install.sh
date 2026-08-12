#!/usr/bin/env bash

set -Eeuo pipefail

install_root="${APPPILOT_INSTALL_ROOT:-$HOME/.local/share/apppilot}"
bin_dir="${APPPILOT_BIN_DIR:-$HOME/.local/bin}"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$install_root" "$bin_dir"
cp -R "$repo_root/bin" "$repo_root/src" "$repo_root/config" "$install_root/"
ln -sfn "$install_root/bin/apppilot" "$bin_dir/apppilot"

"$install_root/bin/apppilot" init --non-interactive >/dev/null

printf 'AppPilot installed.\n\n'
printf 'Command: %s/apppilot\n\n' "$bin_dir"
printf 'Optional dependencies:\n'
command -v pm2 >/dev/null 2>&1 && printf 'PM2            installed\n' || printf 'PM2            not installed\n'
command -v docker >/dev/null 2>&1 && printf 'Docker         installed\n' || printf 'Docker         not installed\n'
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  printf 'Docker Compose installed\n'
else
  printf 'Docker Compose not installed\n'
fi
