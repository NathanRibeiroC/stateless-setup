#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

log() {
  printf '[setup] %s\n' "$1"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
}

is_ubuntu() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == "ubuntu" || "${ID_LIKE:-}" == *"ubuntu"* ]]
    return
  fi
  return 1
}

apt_update_if_needed() {
  local stamp_file="/var/cache/apt/pkgcache.bin"
  local max_age_seconds=21600
  local now last_update age

  now="$(date +%s)"
  if [[ -f "$stamp_file" ]]; then
    last_update="$(stat -c %Y "$stamp_file" 2>/dev/null || echo 0)"
  else
    last_update=0
  fi
  age=$((now - last_update))

  if (( last_update == 0 || age > max_age_seconds )); then
    log "Refreshing apt package index..."
    $SUDO apt-get update -y
  else
    log "Skipping apt update (recent cache found)."
  fi
}

install_packages() {
  local packages=(
    ca-certificates
    curl
    wget
    git
    gnupg
    lsb-release
    software-properties-common
    build-essential
    make
    unzip
    zip
    jq
    ripgrep
    fd-find
    tmux
    tree
    zsh
    python3
    python3-pip
    pipx
    xclip
  )

  log "Installing base development tools..."
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

main() {
  require_cmd apt-get
  require_cmd dpkg

  if ! is_ubuntu; then
    echo "This installer supports Ubuntu systems only."
    exit 1
  fi

  log "Starting Ubuntu stateless setup..."
  apt_update_if_needed
  install_packages

  # Ensure pipx shims are ready for the current user.
  if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath >/dev/null 2>&1 || true
  fi

  log "Setup completed successfully."
}

main "$@"
