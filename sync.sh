#!/usr/bin/env bash
set -euo pipefail

TOTAL_STEPS=11
readonly TOTAL_STEPS
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR
DOTFILES_DIR="$REPO_DIR/dotfiles"
readonly DOTFILES_DIR
DESKTOP_STATE_DIR="$REPO_DIR/desktop-state"
readonly DESKTOP_STATE_DIR
HOME_DIR="$HOME"
readonly HOME_DIR
SECRET_NAME_PATTERNS=("*.key" "*.pem" "id_rsa*" ".env" "*_secret*")
readonly SECRET_NAME_PATTERNS
SECRET_CONTENT_PATTERN='BEGIN [A-Z ]*PRIVATE KEY|api[_-]?key[[:space:]]*[:=]|token[[:space:]]*[:=]|password[[:space:]]*[:=]|AKIA[0-9A-Z]{16}'
readonly SECRET_CONTENT_PATTERN
REQUIRED_COMMANDS=(pacman rsync git pipx flatpak tar zstd sha256sum curl python3)
readonly REQUIRED_COMMANDS

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

run_and_capture() {
  local output_file="$1"
  shift
  "$@" > "$output_file"
}

sync_dotfiles() {
  install -Dm644 "$HOME_DIR/.zshrc" "$DOTFILES_DIR/.zshrc"
  install -Dm644 "$HOME_DIR/.p10k.zsh" "$DOTFILES_DIR/.p10k.zsh"
  mkdir -p "$DOTFILES_DIR/zellij" "$DOTFILES_DIR/oh-my-zsh"
  rsync -a --delete --exclude='.git/' "$HOME_DIR/.config/zellij/" "$DOTFILES_DIR/zellij/"
  rsync -a --delete --exclude='.git/' "$HOME_DIR/.oh-my-zsh/" "$DOTFILES_DIR/oh-my-zsh/"
}

check_for_secret_names() {
  local scan_dir="$1"
  local pattern=''
  for pattern in "${SECRET_NAME_PATTERNS[@]}"; do
    if find "$scan_dir" -type f -name "$pattern" -print -quit | grep -q .; then
      log_error "Potential secret filename detected matching pattern: $pattern"
      return 1
    fi
  done
}

check_for_secret_contents() {
  local scan_dir="$1"
  if command -v rg >/dev/null 2>&1; then
    if rg -n -I -e "$SECRET_CONTENT_PATTERN" "$scan_dir" >/dev/null; then
      log_error 'Potential secret content detected in synced files'
      return 1
    fi
  elif grep -RInI -E "$SECRET_CONTENT_PATTERN" "$scan_dir" >/dev/null 2>&1; then
    log_error 'Potential secret content detected in synced files'
    return 1
  fi
}

git_has_changes() {
  ! git -C "$REPO_DIR" diff --cached --quiet --ignore-submodules --
}

run_preflight() {
  local critical_failed=0
  local warnings_count=0
  local command_name=''
  local required_dir=''
  local branch_name=''

  for command_name in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1; then
      log_success "Preflight command present: $command_name"
    else
      log_error "Preflight command missing (critical): $command_name"
      critical_failed=1
    fi
  done

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    log_error 'Preflight missing GITHUB_TOKEN (critical)'
    critical_failed=1
  else
    log_success 'Preflight GITHUB_TOKEN present'
  fi

  if git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_success 'Preflight repository is valid git work tree'
  else
    log_error 'Preflight repository check failed (critical)'
    critical_failed=1
  fi

  if git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1; then
    log_success 'Preflight origin remote is configured'
  else
    log_error 'Preflight origin remote missing (critical)'
    critical_failed=1
  fi

  for required_dir in "$HOME_DIR" "$HOME_DIR/pentest" "$DOTFILES_DIR" "$DESKTOP_STATE_DIR"; do
    if [[ -d "$required_dir" && -r "$required_dir" ]]; then
      log_success "Preflight directory readable: $required_dir"
    else
      log_error "Preflight directory missing/unreadable (critical): $required_dir"
      critical_failed=1
    fi
  done

  if curl -fsSL --connect-timeout 5 --max-time 10 'https://api.github.com' >/dev/null; then
    log_success 'Preflight GitHub API reachable'
  else
    log_error 'Preflight GitHub API unreachable (critical)'
    critical_failed=1
  fi

  if ! command -v rg >/dev/null 2>&1; then
    log_warn 'Preflight rg not found (warning): secret scanning will fall back to grep'
    warnings_count=$((warnings_count + 1))
  fi

  branch_name="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ "$branch_name" == 'HEAD' ]]; then
    log_warn 'Preflight detached HEAD (warning)'
    warnings_count=$((warnings_count + 1))
  elif [[ -n "$branch_name" && "$branch_name" != 'main' ]]; then
    log_warn "Preflight branch is '$branch_name' instead of 'main' (warning)"
    warnings_count=$((warnings_count + 1))
  fi

  if [[ "$critical_failed" -eq 0 ]]; then
    log_success "Preflight summary: critical_passed=true warnings_count=$warnings_count"
    return 0
  fi

  log_error "Preflight summary: critical_passed=false warnings_count=$warnings_count"
  return 1
}

main() {
  set_current_step 'Running preflight checks'
  log_step 1 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  run_preflight
  log_success 'Preflight checks completed'

  set_current_step 'Updating pacman package list'
  log_step 2 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  run_and_capture "$REPO_DIR/pkglist.pacman.txt" pacman -Qqen
  log_success 'Updated pkglist.pacman.txt'

  set_current_step 'Updating AUR package list'
  log_step 3 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  run_and_capture "$REPO_DIR/pkglist.aur.txt" pacman -Qqem
  log_success 'Updated pkglist.aur.txt'

  set_current_step 'Updating pipx package list'
  log_step 4 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  run_and_capture "$REPO_DIR/pkglist.pipx.txt" pipx list --short
  log_success 'Updated pkglist.pipx.txt'

  set_current_step 'Updating flatpak package list'
  log_step 5 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  run_and_capture "$REPO_DIR/pkglist.flatpak.txt" flatpak list --app --columns=application
  log_success 'Updated pkglist.flatpak.txt'

  set_current_step 'Syncing dotfiles'
  log_step 6 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  sync_dotfiles
  check_for_secret_names "$DOTFILES_DIR"
  check_for_secret_contents "$DOTFILES_DIR"
  log_success 'Synced dotfiles and verified no secrets were detected'

  set_current_step 'Syncing XFCE desktop state'
  log_step 7 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  "$REPO_DIR/scripts/sync_desktop_state.sh"
  check_for_secret_names "$DESKTOP_STATE_DIR"
  check_for_secret_contents "$DESKTOP_STATE_DIR"
  log_success 'Synced XFCE desktop state and verified no secrets were detected'

  set_current_step 'Publishing full pentest snapshot to GitHub Releases'
  log_step 8 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  check_for_secret_names "$HOME_DIR/pentest"
  check_for_secret_contents "$HOME_DIR/pentest"
  "$REPO_DIR/scripts/pentest_release.sh" upload-latest
  log_success 'Published full pentest snapshot to GitHub Releases'

  set_current_step 'Staging git changes'
  log_step 9 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  git -C "$REPO_DIR" add -A
  log_success 'Staged git changes'

  set_current_step 'Creating sync commit when needed'
  log_step 10 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  if git_has_changes; then
    git -C "$REPO_DIR" commit -m "sync: $(date '+%Y-%m-%d %H:%M')"
    log_success 'Created sync commit'
  else
    log_warn 'No changes detected; skipping commit'
  fi

  set_current_step 'Pushing to origin main'
  log_step 11 "$TOTAL_STEPS" "$CURRENT_STEP_MESSAGE"
  git -C "$REPO_DIR" push origin main
  log_success 'Pushed to origin main'
  clear_current_step
}

main "$@"
