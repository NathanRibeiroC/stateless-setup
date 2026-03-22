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
    snapd
    xclip
  )

  log "Installing base development tools..."
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

install_vscode() {
  local keyring_dir="/etc/apt/keyrings"
  local keyring_file="${keyring_dir}/packages.microsoft.gpg"
  local source_file="/etc/apt/sources.list.d/vscode.list"
  local arch

  arch="$(dpkg --print-architecture)"

  log "Configuring Visual Studio Code official repository..."
  $SUDO install -d -m 0755 "$keyring_dir"
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | $SUDO tee "$keyring_file" >/dev/null
  $SUDO chmod a+r "$keyring_file"
  echo "deb [arch=${arch} signed-by=${keyring_file}] https://packages.microsoft.com/repos/code stable main" | $SUDO tee "$source_file" >/dev/null

  log "Installing Visual Studio Code..."
  $SUDO apt-get update -y
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y code
}

install_google_chrome() {
  local keyring_dir="/etc/apt/keyrings"
  local keyring_file="${keyring_dir}/google-linux.gpg"
  local source_file="/etc/apt/sources.list.d/google-chrome.list"
  local arch

  arch="$(dpkg --print-architecture)"

  log "Configuring Google Chrome official repository..."
  $SUDO install -d -m 0755 "$keyring_dir"
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | $SUDO tee "$keyring_file" >/dev/null
  $SUDO chmod a+r "$keyring_file"
  echo "deb [arch=${arch} signed-by=${keyring_file}] https://dl.google.com/linux/chrome/deb/ stable main" | $SUDO tee "$source_file" >/dev/null

  log "Installing Google Chrome..."
  $SUDO apt-get update -y
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y google-chrome-stable
}

install_bitwarden() {
  local keyring_dir="/etc/apt/keyrings"
  local keyring_file="${keyring_dir}/bitwarden.gpg"
  local source_file="/etc/apt/sources.list.d/bitwarden.list"
  local arch

  arch="$(dpkg --print-architecture)"

  log "Configuring Bitwarden official repository..."
  $SUDO install -d -m 0755 "$keyring_dir"
  curl -fsSL https://deb.bitwarden.com/bitwarden.asc | gpg --dearmor | $SUDO tee "$keyring_file" >/dev/null
  $SUDO chmod a+r "$keyring_file"
  echo "deb [arch=${arch} signed-by=${keyring_file}] https://deb.bitwarden.com/ stable main" | $SUDO tee "$source_file" >/dev/null

  log "Installing Bitwarden..."
  $SUDO apt-get update -y
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y bitwarden
}

install_snap_apps() {
  log "Installing Notion and Obsidian via snap..."
  $SUDO snap install notion-snap-reborn
  $SUDO snap install obsidian --classic
}

main() {
  require_cmd apt-get
  require_cmd dpkg
  require_cmd curl
  require_cmd gpg

  if ! is_ubuntu; then
    echo "This installer supports Ubuntu systems only."
    exit 1
  fi

  log "Starting Ubuntu stateless setup..."
  apt_update_if_needed
  install_packages
  install_vscode
  install_google_chrome
  install_bitwarden
  install_snap_apps

  # Ensure pipx shims are ready for the current user.
  if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath >/dev/null 2>&1 || true
  fi

  log "Setup completed successfully."
}

main "$@"
