#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
OS_RELEASE_FILE='/etc/os-release'
readonly OS_RELEASE_FILE

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

ensure_arch_linux() {
  if [ ! -f "$OS_RELEASE_FILE" ] || ! grep -q '^ID=arch' "$OS_RELEASE_FILE"; then
    log_error 'This installer only supports Arch Linux'
    exit 1
  fi
}

ensure_blackarch_keyring() {
  if pacman -Q blackarch-keyring >/dev/null 2>&1; then
    log_warn 'BlackArch keyring already installed'
    return
  fi

  local bootstrap_url='https://blackarch.org/strap.sh'
  local bootstrap_script='/tmp/blackarch-strap.sh'
  require_command curl
  curl -fsSL "$bootstrap_url" -o "$bootstrap_script"
  chmod +x "$bootstrap_script"
  # sudo is required here because the BlackArch bootstrap modifies system package trust.
  sudo "$bootstrap_script"
}

main() {
  set_current_step 'Verifying Arch Linux'
  log_step 1 5 "$CURRENT_STEP_MESSAGE"
  ensure_arch_linux
  log_success 'Arch Linux detected'

  set_current_step 'Ensuring BlackArch keyring is installed'
  log_step 2 5 "$CURRENT_STEP_MESSAGE"
  ensure_blackarch_keyring
  log_success 'BlackArch keyring processed'

  set_current_step 'Installing package manager content'
  log_step 3 5 "$CURRENT_STEP_MESSAGE"
  "$REPO_DIR/scripts/install_packages.sh"
  log_success 'Package installation completed'

  set_current_step 'Installing dotfiles'
  log_step 4 5 "$CURRENT_STEP_MESSAGE"
  "$REPO_DIR/scripts/install_dotfiles.sh"
  log_success 'Dotfiles installation completed'

  set_current_step 'Restoring pentest workspace'
  log_step 5 5 "$CURRENT_STEP_MESSAGE"
  "$REPO_DIR/scripts/install_pentest.sh"
  log_success 'Pentest workspace restoration completed'
  clear_current_step
}

main "$@"