#!/usr/bin/env bash
set -euo pipefail

declare -a search_dirs=(
  "$HOME/.local/bin"
  "$HOME/go/bin"
  "$HOME/bin"
  "$HOME/tools"
  "$HOME/Tools"
  "/usr/local/bin"
)

mapfile -t pipx_packages < <((command -v pipx >/dev/null 2>&1 && pipx list --short 2>/dev/null | awk '{print $1}') || true)
echo 'path,type,owner_guess,sha256,notes'

declare -A seen
for search_dir in "${search_dirs[@]}"; do
  [[ -d "$search_dir" ]] || continue

  while IFS= read -r -d '' candidate; do
    [[ -x "$candidate" ]] || continue
    [[ -n "${seen[$candidate]:-}" ]] && continue
    seen["$candidate"]=1

    if pacman -Qqo "$candidate" >/dev/null 2>&1; then
      continue
    fi

    base_name="$(basename "$candidate")"
    if printf '%s\n' "${pipx_packages[@]}" | grep -Fxq "$base_name"; then
      continue
    fi

    resolved_path="$(readlink -f "$candidate" 2>/dev/null || true)"
    case "$resolved_path" in
      *"/pipx/venvs/"*)
        continue
        ;;
    esac

    if command -v sha256sum >/dev/null 2>&1; then
      checksum="$(sha256sum "$candidate" 2>/dev/null | awk '{print $1}')"
    else
      checksum=''
    fi

    escaped_path="${candidate//\"/\"\"}"
    escaped_checksum="${checksum//\"/\"\"}"
    printf '"%s","executable","unmanaged/manual","%s",""\n' "$escaped_path" "$escaped_checksum"
  done < <(find "$search_dir" -maxdepth 1 \( -type f -o -type l \) -print0 2>/dev/null)
done | sort -u
