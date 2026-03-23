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

warn() {
  printf '[setup][warn] %s\n' "$1" >&2
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

normalize_vscode_repo_entries() {
  local list_file
  # Remove legacy VS Code repository definitions to avoid Signed-By conflicts.
  $SUDO rm -f /etc/apt/sources.list.d/vscode.sources
  for list_file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
    [[ -f "$list_file" ]] || continue
    if grep -q "packages.microsoft.com/repos/code" "$list_file"; then
      $SUDO sed -i '\|packages.microsoft.com/repos/code|d' "$list_file"
    fi
  done
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
    libreoffice
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

install_brave() {
  local keyring_file="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
  local source_file="/etc/apt/sources.list.d/brave-browser-release.list"

  log "Configuring Brave Browser official repository..."
  $SUDO curl -fsSLo "$keyring_file" https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=${keyring_file}] https://brave-browser-apt-release.s3.brave.com/ stable main" | $SUDO tee "$source_file" >/dev/null

  log "Installing Brave Browser..."
  $SUDO apt-get update -y
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y brave-browser
}

install_bitwarden() {
  local keyring_dir="/etc/apt/keyrings"
  local keyring_file="${keyring_dir}/bitwarden.gpg"
  local source_file="/etc/apt/sources.list.d/bitwarden.list"
  local arch

  arch="$(dpkg --print-architecture)"

  log "Configuring Bitwarden official repository..."
  if $SUDO install -d -m 0755 "$keyring_dir" \
    && curl -fsSL https://deb.bitwarden.com/bitwarden.asc | gpg --dearmor | $SUDO tee "$keyring_file" >/dev/null \
    && $SUDO chmod a+r "$keyring_file" \
    && echo "deb [arch=${arch} signed-by=${keyring_file}] https://deb.bitwarden.com/ stable main" | $SUDO tee "$source_file" >/dev/null \
    && $SUDO apt-get update -y \
    && $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y bitwarden; then
    return
  fi

  warn "Bitwarden apt installation failed (network/repository issue). Falling back to snap."
  $SUDO snap install bitwarden
}

install_snap_apps() {
  log "Installing Notion and Obsidian via snap..."
  $SUDO snap install notion-snap-reborn
  $SUDO snap install obsidian --classic
}

get_target_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s\n' "${SUDO_USER}"
  else
    id -un
  fi
}

get_target_home() {
  local target_user="$1"
  if [[ "$target_user" == "root" ]]; then
    printf '/root\n'
  else
    getent passwd "$target_user" | cut -d: -f6
  fi
}

install_node() {
  local target_user target_home nvm_dir install_cmd

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  nvm_dir="${target_home}/.nvm"

  log "Installing Node.js via nvm for user ${target_user}..."

  install_cmd="export NVM_DIR=\"${nvm_dir}\"; \
if [[ ! -s \"${nvm_dir}/nvm.sh\" ]]; then \
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash; \
fi; \
. \"${nvm_dir}/nvm.sh\"; \
nvm install node; \
nvm alias default node"

  if [[ "$target_user" == "root" ]]; then
    bash -lc "$install_cmd"
  else
    $SUDO -u "$target_user" bash -lc "$install_cmd"
  fi
}

install_mise() {
  local target_user target_home install_cmd

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"

  log "Installing mise for user ${target_user}..."

  install_cmd="mkdir -p \"${target_home}/.local/bin\"; \
if [[ ! -x \"${target_home}/.local/bin/mise\" ]]; then \
  curl -fsSL https://mise.run | sh; \
fi"

  if [[ "$target_user" == "root" ]]; then
    bash -lc "$install_cmd"
  else
    $SUDO -u "$target_user" bash -lc "$install_cmd"
  fi
}

install_jetbrains_toolbox() {
  local target_user install_cmd

  target_user="$(get_target_user)"
  log "Installing JetBrains Toolbox for user ${target_user}..."

  install_cmd="set -euo pipefail; \
mkdir -p \"\$HOME/.local/opt\" \"\$HOME/.local/bin\"; \
tmp_dir=\"\$(mktemp -d)\"; \
trap 'rm -rf \"\$tmp_dir\"' EXIT; \
metadata=\"\$(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release')\"; \
download_url=\"\$(printf '%s' \"\$metadata\" | jq -r '.TBA[0].downloads.linux.link // empty')\"; \
if [[ -z \"\$download_url\" ]]; then \
  echo 'Failed to resolve JetBrains Toolbox download URL.'; \
  exit 1; \
fi; \
curl -fL \"\$download_url\" -o \"\$tmp_dir/toolbox.tar.gz\"; \
tar -xzf \"\$tmp_dir/toolbox.tar.gz\" -C \"\$tmp_dir\"; \
extracted_dir=\"\$(find \"\$tmp_dir\" -maxdepth 1 -type d -name 'jetbrains-toolbox-*' | head -n 1)\"; \
if [[ -z \"\$extracted_dir\" ]]; then \
  echo 'Failed to extract JetBrains Toolbox archive.'; \
  exit 1; \
fi; \
rm -rf \"\$HOME/.local/opt/jetbrains-toolbox\"; \
mv \"\$extracted_dir\" \"\$HOME/.local/opt/jetbrains-toolbox\"; \
ln -sf \"\$HOME/.local/opt/jetbrains-toolbox/jetbrains-toolbox\" \"\$HOME/.local/bin/jetbrains-toolbox\""

  if [[ "$target_user" == "root" ]]; then
    bash -lc "$install_cmd"
  else
    $SUDO -u "$target_user" bash -lc "$install_cmd"
  fi
}

install_lazyvim() {
  local target_user target_home nvim_config nvim_data backup_suffix

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  nvim_config="${target_home}/.config/nvim"
  nvim_data="${target_home}/.local/share/nvim"
  backup_suffix="setup-stateless-backup"

  log "Installing Neovim via snap..."
  $SUDO snap install nvim --classic

  if [[ -d "$nvim_config" ]]; then
    log "Neovim config already exists at ${nvim_config}; skipping LazyVim bootstrap."
    return
  fi

  log "Bootstrapping LazyVim starter for user ${target_user}..."
  if [[ -d "${nvim_data}" ]]; then
    $SUDO -u "$target_user" mv "${nvim_data}" "${nvim_data}.${backup_suffix}"
  fi
  $SUDO -u "$target_user" git clone https://github.com/LazyVim/starter "$nvim_config"
  $SUDO -u "$target_user" rm -rf "${nvim_config}/.git"
}

main() {
  require_cmd apt-get
  require_cmd dpkg

  if ! is_ubuntu; then
    echo "This installer supports Ubuntu systems only."
    exit 1
  fi

  log "Starting Ubuntu stateless setup..."
  normalize_vscode_repo_entries
  apt_update_if_needed
  install_packages
  install_vscode
  install_google_chrome
  install_brave
  install_bitwarden
  install_snap_apps
  install_node
  install_mise
  install_jetbrains_toolbox
  install_lazyvim

  # Ensure pipx shims are ready for the current user.
  if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath >/dev/null 2>&1 || true
  fi

  log "Setup completed successfully."
}

main "$@"
