#!/usr/bin/env bash
set -euo pipefail

GITHUB_RELEASE_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly GITHUB_RELEASE_REPO_DIR

get_repo_slug() {
  local remote_url=''
  remote_url="$(git -C "$GITHUB_RELEASE_REPO_DIR" remote get-url origin)"
  case "$remote_url" in
    git@github.com:*.git)
      printf '%s\n' "${remote_url#git@github.com:}" | sed 's/\.git$//'
      ;;
    https://github.com/*.git)
      printf '%s\n' "${remote_url#https://github.com/}" | sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${remote_url#https://github.com/}"
      ;;
    *)
      log_error "Unsupported origin URL: $remote_url"
      exit 1
      ;;
  esac
}

github_api() {
  local method="$1"
  local url="$2"
  local data_file="${3:-}"
  local curl_args=(-fsSL -X "$method" -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  if [ -n "$data_file" ]; then
    curl_args+=(-H 'Content-Type: application/json' --data-binary "@$data_file")
  fi
  curl "${curl_args[@]}" "$url"
}

get_json_value() {
  local expression="$1"
  python3 -c "import json,sys; data=json.load(sys.stdin); value=$expression; print(value if value is not None else '')"
}

get_release_asset_id() {
  local asset_name="$1"
  python3 -c "import json,sys; asset_name=sys.argv[1]; data=json.load(sys.stdin); print(next((str(a.get('id','')) for a in data.get('assets', []) if a.get('name') == asset_name), ''))" "$asset_name"
}

get_release_asset_url() {
  local asset_name="$1"
  python3 -c "import json,sys; asset_name=sys.argv[1]; data=json.load(sys.stdin); print(next((a.get('browser_download_url','') for a in data.get('assets', []) if a.get('name') == asset_name), ''))" "$asset_name"
}