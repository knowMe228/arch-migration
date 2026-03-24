#!/usr/bin/env bash
set -euo pipefail

source /etc/os-release
printf 'hostname=%s\n' "$(hostname)"
printf 'os_name=%s\n' "${NAME:-unknown}"
printf 'os_id=%s\n' "${ID:-unknown}"
printf 'kernel=%s\n' "$(uname -r)"
printf 'arch=%s\n' "$(uname -m)"
printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
