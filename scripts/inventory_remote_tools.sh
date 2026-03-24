#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
PACMAN_LIST="$REPO_DIR/pkglist.pacman.txt"
AUR_LIST="$REPO_DIR/pkglist.aur.txt"
PIPX_LIST="$REPO_DIR/pkglist.pipx.txt"
FLATPAK_LIST="$REPO_DIR/pkglist.flatpak.txt"
BLACKARCH_LIST="$REPO_DIR/pkglist.blackarch.txt"
MANUAL_CSV="$REPO_DIR/arsenal.manual.csv"
SYSTEM_FACTS_TMP="$REPO_DIR/.inventory.system.tmp"
MANUAL_PROBE_SCRIPT="$REPO_DIR/scripts/inventory_manual_probe.sh"
FACTS_PROBE_SCRIPT="$REPO_DIR/scripts/inventory_system_facts_probe.sh"
REPORT_SCRIPT="$REPO_DIR/scripts/inventory_report_generate.sh"

HOST=''
USER_NAME=''
PORT='22'
STRICT='0'
IDENTITY_FILE=''
SSH_TARGET=''
declare -a SSH_EXTRA_OPTS=()
declare -a SSH_BASE_OPTS=()
declare -a SSH_CMD=()

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/inventory_remote_tools.sh --host 192.168.0.176 --user kali [options]

Options:
  --port <num>           SSH port (default: 22)
  --identity <path>      SSH private key path (optional)
  --ssh-option <opt>     Extra SSH option, may be repeated (example: ProxyJump=bastion)
  --strict               Fail immediately on first collection error
  -h, --help             Show help

Notes:
  - Auth is done via regular ssh.
  - Passwords are not stored in the repository.
USAGE
}

cleanup_ssh_control() {
  if [[ -n "$SSH_TARGET" && "${#SSH_BASE_OPTS[@]}" -gt 0 ]]; then
    ssh "${SSH_BASE_OPTS[@]}" -O exit "$SSH_TARGET" >/dev/null 2>&1 || true
  fi
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --host) HOST="${2:-}"; shift 2 ;;
      --user) USER_NAME="${2:-}"; shift 2 ;;
      --port) PORT="${2:-}"; shift 2 ;;
      --identity) IDENTITY_FILE="${2:-}"; shift 2 ;;
      --ssh-option) SSH_EXTRA_OPTS+=("${2:-}"); shift 2 ;;
      --strict) STRICT='1'; shift ;;
      -h|--help) usage; exit 0 ;;
      *)
        log_error "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$HOST" || -z "$USER_NAME" ]]; then
    usage
    exit 1
  fi

  if [[ -n "$IDENTITY_FILE" && ! -f "$IDENTITY_FILE" ]]; then
    log_error "Identity file not found: $IDENTITY_FILE"
    exit 1
  fi

  if [[ ! -f "$MANUAL_PROBE_SCRIPT" || ! -f "$FACTS_PROBE_SCRIPT" || ! -f "$REPORT_SCRIPT" ]]; then
    log_error 'Required helper scripts are missing'
    exit 1
  fi
}

capture_remote_command() {
  local description="$1"
  local output_file="$2"
  local fallback_content="$3"
  local remote_command="$4"
  local tmp_file
  tmp_file="$(mktemp)"

  if "${SSH_CMD[@]}" "bash -lc \"$remote_command\"" >"$tmp_file"; then
    tr -d '\r' <"$tmp_file" >"$output_file"
    rm -f "$tmp_file"
    log_success "$description -> $(basename "$output_file")"
    return
  fi

  rm -f "$tmp_file"
  if [[ "$STRICT" == '1' ]]; then
    log_error "$description failed in --strict mode"
    exit 1
  fi

  log_warn "$description failed; writing fallback output"
  if [[ -n "$fallback_content" ]]; then
    printf '%s\n' "$fallback_content" >"$output_file"
  else
    : >"$output_file"
  fi
}

capture_remote_script_file() {
  local description="$1"
  local output_file="$2"
  local fallback_content="$3"
  local local_script_path="$4"
  local tmp_file
  tmp_file="$(mktemp)"

  if "${SSH_CMD[@]}" 'bash -s' <"$local_script_path" >"$tmp_file"; then
    tr -d '\r' <"$tmp_file" >"$output_file"
    rm -f "$tmp_file"
    log_success "$description -> $(basename "$output_file")"
    return
  fi

  rm -f "$tmp_file"
  if [[ "$STRICT" == '1' ]]; then
    log_error "$description failed in --strict mode"
    exit 1
  fi

  log_warn "$description failed; writing fallback output"
  printf '%s\n' "$fallback_content" >"$output_file"
}

build_ssh_options() {
  SSH_BASE_OPTS=(
    -p "$PORT"
    -o StrictHostKeyChecking=accept-new
    -o ControlMaster=auto
    -o ControlPersist=300
    -o ControlPath='/tmp/pentest-inv-%r@%h:%p'
  )

  if [[ -n "$IDENTITY_FILE" ]]; then
    SSH_BASE_OPTS+=( -i "$IDENTITY_FILE" )
  fi

  local opt
  for opt in "${SSH_EXTRA_OPTS[@]}"; do
    SSH_BASE_OPTS+=( -o "$opt" )
  done
}

main() {
  trap cleanup_ssh_control EXIT
  parse_args "$@"

  SSH_TARGET="$USER_NAME@$HOST"
  build_ssh_options
  SSH_CMD=(ssh "${SSH_BASE_OPTS[@]}" "$SSH_TARGET")

  set_current_step 'Opening SSH control connection'
  log_step 1 5 "$CURRENT_STEP_MESSAGE"
  "${SSH_CMD[@]}" 'true' >/dev/null
  log_success 'SSH authenticated'

  set_current_step 'Collecting package-manager manifests'
  log_step 2 5 "$CURRENT_STEP_MESSAGE"
  capture_remote_command 'pacman explicit packages' "$PACMAN_LIST" '' 'pacman -Qqen 2>/dev/null | sort -u'
  capture_remote_command 'AUR/foreign packages' "$AUR_LIST" '' 'pacman -Qqem 2>/dev/null | sort -u'
  capture_remote_command 'pipx packages' "$PIPX_LIST" '' "if command -v pipx >/dev/null 2>&1; then pipx list --short 2>/dev/null | sed -E 's/[[:space:]].*$//' | sort -u; fi"
  capture_remote_command 'flatpak apps' "$FLATPAK_LIST" '' "if command -v flatpak >/dev/null 2>&1; then flatpak list --app --columns=application 2>/dev/null | sed '/^Application ID$/d' | sort -u; fi"
  capture_remote_command 'blackarch intersection list' "$BLACKARCH_LIST" '' 'if pacman -Slq blackarch >/dev/null 2>&1; then comm -12 <(pacman -Qq | sort -u) <(pacman -Slq blackarch | sort -u); fi'

  set_current_step 'Collecting manual-tool inventory and system facts'
  log_step 3 5 "$CURRENT_STEP_MESSAGE"
  capture_remote_script_file 'manual-tool inventory' "$MANUAL_CSV" 'path,type,owner_guess,sha256,notes' "$MANUAL_PROBE_SCRIPT"
  capture_remote_script_file 'system facts' "$SYSTEM_FACTS_TMP" '' "$FACTS_PROBE_SCRIPT"

  set_current_step 'Generating arsenal.report.md'
  log_step 4 5 "$CURRENT_STEP_MESSAGE"
  "$REPORT_SCRIPT"

  set_current_step 'Inventory complete'
  log_step 5 5 "$CURRENT_STEP_MESSAGE"
  log_success 'All inventory artifacts updated'
  clear_current_step
}

main "$@"
