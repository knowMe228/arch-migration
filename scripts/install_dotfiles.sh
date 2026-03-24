#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
DOTFILES_DIR="$REPO_DIR/dotfiles"
readonly DOTFILES_DIR
HOME_DIR="$HOME"
readonly HOME_DIR
BACKUP_SUFFIX="$(date '+%Y%m%d')"
readonly BACKUP_SUFFIX

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

backup_path() {
  local target_path="$1"
  local backup_path=''
  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    backup_path="$target_path.bak-$BACKUP_SUFFIX"
    if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
      log_error "Backup already exists, refusing to overwrite: $backup_path"
      return 1
    fi
    mv "$target_path" "$backup_path"
  fi
}

link_with_backup() {
  local source_path="$1"
  local target_path="$2"
  local target_dir=''
  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir"

  if [ -L "$target_path" ] && [ "$(readlink -f "$target_path")" = "$(readlink -f "$source_path")" ]; then
    log_warn "Already linked: $target_path"
    return
  fi

  backup_path "$target_path"
  ln -sfn "$source_path" "$target_path"
}

main() {
  set_current_step 'Linking .zshrc'
  log_step 1 4 "$CURRENT_STEP_MESSAGE"
  link_with_backup "$DOTFILES_DIR/.zshrc" "$HOME_DIR/.zshrc"
  log_success 'Installed .zshrc'

  set_current_step 'Linking .p10k.zsh'
  log_step 2 4 "$CURRENT_STEP_MESSAGE"
  link_with_backup "$DOTFILES_DIR/.p10k.zsh" "$HOME_DIR/.p10k.zsh"
  log_success 'Installed .p10k.zsh'

  set_current_step 'Linking zellij config'
  log_step 3 4 "$CURRENT_STEP_MESSAGE"
  link_with_backup "$DOTFILES_DIR/zellij" "$HOME_DIR/.config/zellij"
  log_success 'Installed zellij config'

  set_current_step 'Linking full oh-my-zsh config'
  log_step 4 4 "$CURRENT_STEP_MESSAGE"
  link_with_backup "$DOTFILES_DIR/oh-my-zsh" "$HOME_DIR/.oh-my-zsh"
  log_success 'Installed full oh-my-zsh config'
  clear_current_step
}

main "$@"