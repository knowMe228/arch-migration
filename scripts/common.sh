#!/usr/bin/env bash
set -euo pipefail

readonly COLOR_BLUE='\033[1;34m'
readonly COLOR_GREEN='\033[1;32m'
readonly COLOR_RED='\033[1;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RESET='\033[0m'

CURRENT_STEP_MESSAGE=''

log_step() {
  local step="$1"
  local total="$2"
  local message="$3"
  printf '%b[STEP %s/%s]%b %s\n' "$COLOR_BLUE" "$step" "$total" "$COLOR_RESET" "$message"
}

log_success() {
  local message="$1"
  printf '%b✔%b %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$message"
}

log_warn() {
  local message="$1"
  printf '%b!%b %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$message"
}

log_error() {
  local message="$1"
  printf '%b✗%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$message" >&2
}

set_current_step() {
  CURRENT_STEP_MESSAGE="$1"
}

clear_current_step() {
  CURRENT_STEP_MESSAGE=''
}

handle_unexpected_error() {
  local exit_code="$1"
  local line_number="$2"
  local failed_command="$3"
  if [ -n "$CURRENT_STEP_MESSAGE" ]; then
    log_error "$CURRENT_STEP_MESSAGE failed at line $line_number while running: $failed_command"
  else
    log_error "Command failed at line $line_number: $failed_command"
  fi
  exit "$exit_code"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    log_error "Required command not found: $command_name"
    exit 1
  fi
}

file_has_entries() {
  local file_path="$1"
  grep -q '[^[:space:]]' "$file_path"
}