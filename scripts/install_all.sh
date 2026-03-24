#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
OS_RELEASE_FILE='/etc/os-release'
readonly OS_RELEASE_FILE
BLACKARCH_LIST="$REPO_DIR/pkglist.blackarch.txt"
MANUAL_TOOLS_FILE="$REPO_DIR/arsenal.manual.csv"

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

ensure_arch_linux() {
  if [[ ! -f "$OS_RELEASE_FILE" ]] || ! grep -q '^ID=arch' "$OS_RELEASE_FILE"; then
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
  sudo "$bootstrap_script"
}

manifest_entries() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  grep -Ev '^\s*(#|$|Application ID$)' "$file_path" || true
}

validate_blackarch_manifest() {
  if [[ ! -f "$BLACKARCH_LIST" ]]; then
    log_warn 'pkglist.blackarch.txt not found; skip validation'
    return 0
  fi

  mapfile -t blackarch_packages < <(manifest_entries "$BLACKARCH_LIST")
  if [[ "${#blackarch_packages[@]}" -eq 0 ]]; then
    log_warn 'pkglist.blackarch.txt is empty'
    return 0
  fi

  local missing_packages=()
  local package_name
  for package_name in "${blackarch_packages[@]}"; do
    if ! pacman -Q "$package_name" >/dev/null 2>&1; then
      missing_packages+=("$package_name")
    fi
  done

  if [[ "${#missing_packages[@]}" -eq 0 ]]; then
    log_success "BlackArch manifest validated (${#blackarch_packages[@]} packages present)"
    return 0
  fi

  log_warn "BlackArch manifest missing ${#missing_packages[@]} package(s)"
  printf '  - %s\n' "${missing_packages[@]}"
}

warn_manual_tools() {
  if [[ ! -f "$MANUAL_TOOLS_FILE" ]]; then
    log_warn 'arsenal.manual.csv not found; no manual-tool warnings'
    return 0
  fi

  local manual_count
  manual_count="$(awk -F, 'NR > 1 && $1 != "" {count++} END {print count + 0}' "$MANUAL_TOOLS_FILE")"

  if [[ "$manual_count" -eq 0 ]]; then
    log_success 'No unmanaged/manual tools listed'
    return 0
  fi

  log_warn "Found $manual_count unmanaged/manual tool(s); install manually"
  awk -F, 'NR > 1 && shown < 20 {
    gsub(/^"|"$/, "", $1);
    printf "  - %s\n", $1;
    shown++
  }' "$MANUAL_TOOLS_FILE"

  if [[ "$manual_count" -gt 20 ]]; then
    log_warn 'Only first 20 manual tools are shown above'
  fi
}

main() {
  set_current_step 'Verifying Arch Linux'
  log_step 1 8 "$CURRENT_STEP_MESSAGE"
  ensure_arch_linux
  log_success 'Arch Linux detected'

  set_current_step 'Ensuring BlackArch keyring is installed'
  log_step 2 8 "$CURRENT_STEP_MESSAGE"
  ensure_blackarch_keyring
  log_success 'BlackArch keyring processed'

  set_current_step 'Installing package manager content'
  log_step 3 8 "$CURRENT_STEP_MESSAGE"
  "$REPO_DIR/scripts/install_packages.sh"
  log_success 'Package installation completed'

  set_current_step 'Installing dotfiles'
  log_step 4 8 "$CURRENT_STEP_MESSAGE"
  "$REPO_DIR/scripts/install_dotfiles.sh"
  log_success 'Dotfiles installation completed'

  set_current_step 'Restoring XFCE desktop state'
  log_step 5 8 "$CURRENT_STEP_MESSAGE"
  "$REPO_DIR/scripts/install_desktop_state.sh"
  log_success 'XFCE desktop state restoration completed'

  set_current_step 'Restoring pentest workspace'
  log_step 6 8 "$CURRENT_STEP_MESSAGE"
  "$REPO_DIR/scripts/install_pentest.sh"
  log_success 'Pentest workspace restoration completed'

  set_current_step 'Validating BlackArch manifest (report only)'
  log_step 7 8 "$CURRENT_STEP_MESSAGE"
  validate_blackarch_manifest

  set_current_step 'Checking unmanaged/manual tools (report only)'
  log_step 8 8 "$CURRENT_STEP_MESSAGE"
  warn_manual_tools

  clear_current_step
}

main "$@"
