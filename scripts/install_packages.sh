#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
PACMAN_LIST="$REPO_DIR/pkglist.pacman.txt"
readonly PACMAN_LIST
AUR_LIST="$REPO_DIR/pkglist.aur.txt"
readonly AUR_LIST
PIPX_LIST="$REPO_DIR/pkglist.pipx.txt"
readonly PIPX_LIST
FLATPAK_LIST="$REPO_DIR/pkglist.flatpak.txt"
readonly FLATPAK_LIST

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

install_pacman_packages() {
  local packages=()
  if file_has_entries "$PACMAN_LIST"; then
    mapfile -t packages < "$PACMAN_LIST"
    # sudo is required here because pacman installs system packages.
    sudo pacman -S --needed --noconfirm "${packages[@]}"
  else
    log_warn 'pkglist.pacman.txt is empty; skipping pacman packages'
  fi
}

install_aur_packages() {
  local packages=()
  if ! file_has_entries "$AUR_LIST"; then
    log_warn 'pkglist.aur.txt is empty; skipping AUR packages'
    return
  fi
  if ! command -v yay >/dev/null 2>&1; then
    log_warn 'yay is not installed; skipping AUR packages'
    return
  fi
  mapfile -t packages < "$AUR_LIST"
  yay -S --needed --noconfirm "${packages[@]}"
}

install_pipx_packages() {
  if ! command -v pipx >/dev/null 2>&1; then
    log_warn 'pipx is not installed; skipping pipx packages'
    return
  fi
  if file_has_entries "$PIPX_LIST"; then
    while IFS= read -r package_name; do
      [ -n "$package_name" ] || continue
      if pipx list --short 2>/dev/null | grep -Fxq "$package_name"; then
        log_warn "pipx package already installed: $package_name"
        continue
      fi
      pipx install "$package_name"
    done < "$PIPX_LIST"
  else
    log_warn 'pkglist.pipx.txt is empty; skipping pipx packages'
  fi
}

install_flatpak_packages() {
  if ! command -v flatpak >/dev/null 2>&1; then
    log_warn 'flatpak is not installed; skipping Flatpak packages'
    return
  fi
  if file_has_entries "$FLATPAK_LIST"; then
    while IFS= read -r package_name; do
      [ -n "$package_name" ] || continue
      if flatpak list --app --columns=application | grep -Fxq "$package_name"; then
        log_warn "Flatpak already installed: $package_name"
        continue
      fi
      flatpak install -y "$package_name"
    done < "$FLATPAK_LIST"
  else
    log_warn 'pkglist.flatpak.txt is empty; skipping Flatpak packages'
  fi
}

main() {
  set_current_step 'Installing pacman packages'
  log_step 1 4 "$CURRENT_STEP_MESSAGE"
  install_pacman_packages
  log_success 'Pacman packages processed'

  set_current_step 'Installing AUR packages'
  log_step 2 4 "$CURRENT_STEP_MESSAGE"
  install_aur_packages
  log_success 'AUR packages processed'

  set_current_step 'Installing pipx packages'
  log_step 3 4 "$CURRENT_STEP_MESSAGE"
  install_pipx_packages
  log_success 'pipx packages processed'

  set_current_step 'Installing Flatpak packages'
  log_step 4 4 "$CURRENT_STEP_MESSAGE"
  install_flatpak_packages
  log_success 'Flatpak packages processed'
  clear_current_step
}

main "$@"