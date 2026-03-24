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
REPORT_FILE="$REPO_DIR/arsenal.report.md"
SYSTEM_FACTS_TMP="$REPO_DIR/.inventory.system.tmp"

source "$REPO_DIR/scripts/common.sh"
trap 'handle_unexpected_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

count_entries() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    echo 0
    return
  fi

  grep -Ecv '^\s*(#|$|Application ID$)' "$file_path"
}

append_markdown_list_from_file() {
  local input_file="$1"
  if [[ ! -s "$input_file" ]]; then
    printf -- '- (none)\n' >>"$REPORT_FILE"
    return
  fi

  grep -Ev '^\s*(#|$|Application ID$)' "$input_file" | sed 's/^/- `/' | sed 's/$/`/' >>"$REPORT_FILE"
}

append_risk_section() {
  local manual_count="$1"

  printf '\n## Top Manual Tools By Risk\n' >>"$REPORT_FILE"
  if [[ "$manual_count" -eq 0 ]]; then
    printf -- '- (none)\n' >>"$REPORT_FILE"
    return
  fi

  awk -F, '
    NR == 1 {next}
    $1 == "" {next}
    {
      gsub(/^"|"$/, "", $1)
      path = $1
      risk = "medium"
      score = 2

      if (path ~ /^\/usr\/local\/bin\// || path ~ /^\/opt\//) {
        risk = "high"
        score = 3
      } else if (path ~ /\/\.local\/bin\//) {
        risk = "low"
        score = 1
      }

      printf "%d\t%s\t%s\n", score, risk, path
    }
  ' "$MANUAL_CSV" | sort -t $'\t' -k1,1nr -k3,3 | head -n 15 | awk -F $'\t' '{printf "- [%s] `%s`\n", $2, $3}' >>"$REPORT_FILE"
}

generate_report() {
  local pacman_count aur_count pipx_count flatpak_count blackarch_count manual_count
  local host_name os_name os_id kernel arch captured_at

  pacman_count="$(count_entries "$PACMAN_LIST")"
  aur_count="$(count_entries "$AUR_LIST")"
  pipx_count="$(count_entries "$PIPX_LIST")"
  flatpak_count="$(count_entries "$FLATPAK_LIST")"
  blackarch_count="$(count_entries "$BLACKARCH_LIST")"
  manual_count="$(awk -F, 'NR > 1 && $1 != "" {count++} END {print count + 0}' "$MANUAL_CSV")"

  host_name="$(grep '^hostname=' "$SYSTEM_FACTS_TMP" | head -n1 | cut -d'=' -f2-)"
  os_name="$(grep '^os_name=' "$SYSTEM_FACTS_TMP" | head -n1 | cut -d'=' -f2-)"
  os_id="$(grep '^os_id=' "$SYSTEM_FACTS_TMP" | head -n1 | cut -d'=' -f2-)"
  kernel="$(grep '^kernel=' "$SYSTEM_FACTS_TMP" | head -n1 | cut -d'=' -f2-)"
  arch="$(grep '^arch=' "$SYSTEM_FACTS_TMP" | head -n1 | cut -d'=' -f2-)"
  captured_at="$(grep '^timestamp_utc=' "$SYSTEM_FACTS_TMP" | head -n1 | cut -d'=' -f2-)"

  cat >"$REPORT_FILE" <<EOF_REPORT
# Arsenal Report

## System Facts
- host: $host_name
- os: $os_name ($os_id)
- kernel: $kernel
- architecture: $arch
- captured_utc: $captured_at

## Counts By Source
| source | count |
|---|---:|
| pacman explicit | $pacman_count |
| AUR/foreign | $aur_count |
| pipx | $pipx_count |
| flatpak apps | $flatpak_count |
| blackarch subset | $blackarch_count |
| unmanaged/manual | $manual_count |

## Install-Ready (Automatic)
- pkglist.pacman.txt
- pkglist.aur.txt
- pkglist.pipx.txt
- pkglist.flatpak.txt
- pkglist.blackarch.txt (validation/report only)

## BlackArch Tools
EOF_REPORT

  append_markdown_list_from_file "$BLACKARCH_LIST"
  printf '\n## pipx Tools\n' >>"$REPORT_FILE"
  append_markdown_list_from_file "$PIPX_LIST"
  printf '\n## Flatpak Apps\n' >>"$REPORT_FILE"
  append_markdown_list_from_file "$FLATPAK_LIST"
  printf '\n## Unmanaged/Manual Tools\n' >>"$REPORT_FILE"

  if [[ "$manual_count" -eq 0 ]]; then
    printf -- '- (none)\n' >>"$REPORT_FILE"
  else
    awk -F, 'NR > 1 && $1 != "" {gsub(/^"|"$/, "", $1); printf "- `%s`\n", $1}' "$MANUAL_CSV" >>"$REPORT_FILE"
  fi

  append_risk_section "$manual_count"

  printf "\n## Install Gaps\n- Automatic install covers package-manager manifests above.\n- Manual follow-up required for %s unmanaged/manual tool(s) listed in \`arsenal.manual.csv\`.\n" "$manual_count" >>"$REPORT_FILE"

  rm -f "$SYSTEM_FACTS_TMP"
  log_success "Generated $(basename "$REPORT_FILE")"
}

generate_report
