#!/usr/bin/env bash

color_setup() {
  if [[ -t 1 && "${NO_COLOR:-}" == "" && "${APPPILOT_JSON:-0}" != "1" ]]; then
    APPPILOT_COLOR_GREEN=$'\033[32m'
    APPPILOT_COLOR_YELLOW=$'\033[33m'
    APPPILOT_COLOR_RED=$'\033[31m'
    APPPILOT_COLOR_BOLD=$'\033[1m'
    APPPILOT_COLOR_RESET=$'\033[0m'
  else
    APPPILOT_COLOR_GREEN=""
    APPPILOT_COLOR_YELLOW=""
    APPPILOT_COLOR_RED=""
    APPPILOT_COLOR_BOLD=""
    APPPILOT_COLOR_RESET=""
  fi
}

color_setup
