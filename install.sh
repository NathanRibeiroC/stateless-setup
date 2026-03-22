#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f /etc/os-release ]]; then
  echo "Cannot detect Linux distribution: /etc/os-release not found."
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

run_installer() {
  local installer="$1"
  if [[ ! -x "$installer" ]]; then
    chmod +x "$installer"
  fi
  bash "$installer"
}

case "${ID:-}" in
  ubuntu)
    run_installer "${SCRIPT_DIR}/installers/ubuntu.sh"
    ;;
  *)
    if [[ "${ID_LIKE:-}" == *"ubuntu"* || "${ID_LIKE:-}" == *"debian"* ]]; then
      run_installer "${SCRIPT_DIR}/installers/ubuntu.sh"
    else
      echo "Unsupported distribution: ${ID:-unknown}"
      echo "Currently supported: ubuntu"
      exit 1
    fi
    ;;
esac
