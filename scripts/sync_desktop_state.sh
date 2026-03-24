#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
HOME_DIR="$HOME"
readonly HOME_DIR
DESKTOP_STATE_DIR="$REPO_DIR/desktop-state/xfce"
readonly DESKTOP_STATE_DIR

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

sync_tree() {
  local source_path="$1"
  local target_path="$2"

  if [[ ! -e "$source_path" ]]; then
    log_warn "Skipping missing path: $source_path"
    return 0
  fi

  mkdir -p "$target_path"
  rsync -a --delete --exclude='.git/' --exclude='*.lock' "$source_path/" "$target_path/"
  log_success "Synced $source_path"
}

main() {
  require_command rsync
  mkdir -p "$DESKTOP_STATE_DIR"

  log_step 1 4 'Syncing XFCE core settings'
  sync_tree "$HOME_DIR/.config/xfce4" "$DESKTOP_STATE_DIR/.config/xfce4"

  log_step 2 4 'Syncing panel launchers and application entries'
  sync_tree "$HOME_DIR/.local/share/xfce4" "$DESKTOP_STATE_DIR/.local/share/xfce4"
  sync_tree "$HOME_DIR/.local/share/applications" "$DESKTOP_STATE_DIR/.local/share/applications"

  log_step 3 4 'Syncing GTK and file-manager preferences'
  sync_tree "$HOME_DIR/.config/gtk-3.0" "$DESKTOP_STATE_DIR/.config/gtk-3.0"
  sync_tree "$HOME_DIR/.config/gtk-4.0" "$DESKTOP_STATE_DIR/.config/gtk-4.0"
  sync_tree "$HOME_DIR/.config/Thunar" "$DESKTOP_STATE_DIR/.config/Thunar"

  log_step 4 4 'Syncing themes/icons and desktop shortcuts'
  sync_tree "$HOME_DIR/.themes" "$DESKTOP_STATE_DIR/.themes"
  sync_tree "$HOME_DIR/.icons" "$DESKTOP_STATE_DIR/.icons"
  sync_tree "$HOME_DIR/Desktop" "$DESKTOP_STATE_DIR/Desktop"

  log_success 'XFCE desktop state synced'
}

main "$@"
