#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
HOME_DIR="$HOME"
readonly HOME_DIR
DESKTOP_STATE_DIR="$REPO_DIR/desktop-state/xfce"
readonly DESKTOP_STATE_DIR
BACKUP_SUFFIX="$(date '+%Y%m%d')"
readonly BACKUP_SUFFIX

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

backup_path() {
  local target_path="$1"
  local backup_path=''

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    backup_path="$target_path.bak-$BACKUP_SUFFIX"
    if [[ -e "$backup_path" || -L "$backup_path" ]]; then
      log_error "Backup already exists, refusing to overwrite: $backup_path"
      return 1
    fi
    mv "$target_path" "$backup_path"
    log_success "Backed up $target_path"
  fi
}

install_tree() {
  local source_path="$1"
  local target_path="$2"

  if [[ ! -d "$source_path" ]]; then
    log_warn "Skipping missing desktop-state path: $source_path"
    return 0
  fi

  backup_path "$target_path"
  mkdir -p "$target_path"
  rsync -a --delete --exclude='.git/' "$source_path/" "$target_path/"
  log_success "Installed $target_path"
}

main() {
  require_command rsync

  log_step 1 4 'Restoring XFCE core settings'
  install_tree "$DESKTOP_STATE_DIR/.config/xfce4" "$HOME_DIR/.config/xfce4"

  log_step 2 4 'Restoring panel launchers, dock, and application entries'
  install_tree "$DESKTOP_STATE_DIR/.local/share/xfce4" "$HOME_DIR/.local/share/xfce4"
  install_tree "$DESKTOP_STATE_DIR/.local/share/applications" "$HOME_DIR/.local/share/applications"
  install_tree "$DESKTOP_STATE_DIR/.config/plank" "$HOME_DIR/.config/plank"
  install_tree "$DESKTOP_STATE_DIR/.local/share/plank" "$HOME_DIR/.local/share/plank"

  log_step 3 4 'Restoring GTK and file-manager preferences'
  install_tree "$DESKTOP_STATE_DIR/.config/gtk-3.0" "$HOME_DIR/.config/gtk-3.0"
  install_tree "$DESKTOP_STATE_DIR/.config/gtk-4.0" "$HOME_DIR/.config/gtk-4.0"
  install_tree "$DESKTOP_STATE_DIR/.config/Thunar" "$HOME_DIR/.config/Thunar"

  log_step 4 4 'Restoring themes/icons and desktop shortcuts'
  install_tree "$DESKTOP_STATE_DIR/.themes" "$HOME_DIR/.themes"
  install_tree "$DESKTOP_STATE_DIR/.icons" "$HOME_DIR/.icons"
  install_tree "$DESKTOP_STATE_DIR/Desktop" "$HOME_DIR/Desktop"

  log_success 'XFCE desktop state restored'
}

main "$@"
