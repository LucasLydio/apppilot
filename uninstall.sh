#!/usr/bin/env bash

set -Eeuo pipefail

install_root="${APPPILOT_INSTALL_ROOT:-$HOME/.local/share/apppilot}"
bin_path="${APPPILOT_BIN_DIR:-$HOME/.local/bin}/apppilot"

rm -f "$bin_path"
rm -rf "$install_root"

printf 'AppPilot uninstalled. User configuration was preserved.\n'
