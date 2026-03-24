#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
PACMAN_LIST="$REPO_DIR/pkglist.pacman.txt"
AUR_LIST="$REPO_DIR/pkglist.aur.txt"
PIPX_LIST="$REPO_DIR/pkglist.pipx.txt"
FLATPAK_LIST="$REPO_DIR/pkglist.flatpak.txt"

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

read_list_items() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  grep -Ev '^\s*(#|$|Application ID$)' "$file_path" || true
}

install_pacman_packages() {
  if ! command -v pacman >/dev/null 2>&1; then
    log_error "pacman not found"
    return 1
  fi

  mapfile -t packages < <(read_list_items "$PACMAN_LIST")
  if [[ "${#packages[@]}" -eq 0 ]]; then
    log_warn "pkglist.pacman.txt is empty"
    return 0
  fi

  sudo pacman -S --needed --noconfirm "${packages[@]}"
}

install_aur_packages() {
  mapfile -t packages < <(read_list_items "$AUR_LIST")
  if [[ "${#packages[@]}" -eq 0 ]]; then
    log_warn "pkglist.aur.txt is empty"
    return 0
  fi

  if ! command -v yay >/dev/null 2>&1; then
    log_warn "yay is not installed; skipping AUR packages"
    return 0
  fi

  yay -S --needed --noconfirm "${packages[@]}"
}

install_pipx_packages() {
  mapfile -t packages < <(read_list_items "$PIPX_LIST")
  if [[ "${#packages[@]}" -eq 0 ]]; then
    log_warn "pkglist.pipx.txt is empty"
    return 0
  fi

  if ! command -v pipx >/dev/null 2>&1; then
    log_warn "pipx is not installed; skipping pipx packages"
    return 0
  fi

  mapfile -t installed < <(pipx list --short 2>/dev/null | awk '{print $1}' || true)
  for package_name in "${packages[@]}"; do
    if printf '%s\n' "${installed[@]}" | grep -Fxq "$package_name"; then
      log_warn "pipx package already installed: $package_name"
      continue
    fi

    pipx install "$package_name"
  done
}

install_flatpak_packages() {
  mapfile -t apps < <(read_list_items "$FLATPAK_LIST")
  if [[ "${#apps[@]}" -eq 0 ]]; then
    log_warn "pkglist.flatpak.txt is empty"
    return 0
  fi

  if ! command -v flatpak >/dev/null 2>&1; then
    log_warn "flatpak is not installed; skipping Flatpak packages"
    return 0
  fi

  for app_id in "${apps[@]}"; do
    if flatpak list --app --columns=application | grep -Fxq "$app_id"; then
      log_warn "Flatpak already installed: $app_id"
      continue
    fi

    flatpak install -y flathub "$app_id"
  done
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
