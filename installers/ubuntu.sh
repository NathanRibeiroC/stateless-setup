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

run_as_target_user() {
  local target_user="$1"
  shift

  if [[ "$target_user" == "root" ]]; then
    bash -lc "$*"
  else
    $SUDO -u "$target_user" bash -lc "$*"
  fi
}

write_file_as_target_user() {
  local target_user="$1"
  local destination="$2"

  if [[ "$target_user" == "root" ]]; then
    cat > "$destination"
  else
    $SUDO -u "$target_user" tee "$destination" >/dev/null
  fi
}

append_file_as_target_user() {
  local target_user="$1"
  local destination="$2"

  if [[ "$target_user" == "root" ]]; then
    cat >> "$destination"
  else
    $SUDO -u "$target_user" tee -a "$destination" >/dev/null
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
    alacritty
    python3
    python3-pip
    pipx
    libreoffice
    snapd
    xclip
    rclone
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

install_starship() {
  local target_user target_home install_cmd

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"

  log "Installing Starship prompt for user ${target_user}..."

  install_cmd="mkdir -p \"${target_home}/.local/bin\"; \
if [[ ! -x \"${target_home}/.local/bin/starship\" ]]; then \
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b \"${target_home}/.local/bin\"; \
fi"

  run_as_target_user "$target_user" "$install_cmd"
}

install_jetbrains_mono_nerd_font() {
  local target_user target_home font_dir install_cmd

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  font_dir="${target_home}/.local/share/fonts"

  log "Installing JetBrainsMono Nerd Font for user ${target_user}..."

  install_cmd="mkdir -p \"${font_dir}\"; \
if ! find \"${font_dir}\" -maxdepth 1 -type f -name 'JetBrainsMono*NerdFont*.ttf' | grep -q .; then \
  tmp_dir=\$(mktemp -d); \
  trap 'rm -rf \"\${tmp_dir}\"' EXIT; \
  curl -fsSL -o \"\${tmp_dir}/JetBrainsMono.zip\" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip; \
  unzip -qo \"\${tmp_dir}/JetBrainsMono.zip\" -d \"\${tmp_dir}/fonts\"; \
  find \"\${tmp_dir}/fonts\" -type f -name '*.ttf' ! -name '*Windows Compatible*' -exec cp {} \"${font_dir}/\" \;; \
fi; \
fc-cache -f \"${font_dir}\" >/dev/null 2>&1 || true"

  run_as_target_user "$target_user" "$install_cmd"
}

configure_alacritty() {
  local target_user target_home config_dir config_file

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  config_dir="${target_home}/.config/alacritty"
  config_file="${config_dir}/alacritty.toml"

  log "Writing Alacritty config for user ${target_user}..."
  $SUDO install -d -m 0755 -o "$target_user" -g "$target_user" "$config_dir"
  cat <<'EOF' | write_file_as_target_user "$target_user" "$config_file"
[window]
opacity = 0.88
startup_mode = "Maximized"
decorations = "Full"
decorations_theme_variant = "Dark"

[window.padding]
x = 10
y = 10

[colors.primary]
background = "#2b3139"
foreground = "#d6dde5"

[colors.cursor]
text = "#2b3139"
cursor = "#d6dde5"

[colors.selection]
text = "#d6dde5"
background = "#46515d"

[font]
size = 12.5
builtin_box_drawing = true

[font.normal]
family = "JetBrainsMono Nerd Font"
style = "Regular"

[font.bold]
family = "JetBrainsMono Nerd Font"
style = "Bold"

[font.italic]
family = "JetBrainsMono Nerd Font"
style = "Italic"

[font.bold_italic]
family = "JetBrainsMono Nerd Font"
style = "Bold Italic"

[cursor]
style = { shape = "Beam", blinking = "On" }
blink_interval = 700
unfocused_hollow = true

[scrolling]
history = 20000
multiplier = 3

[selection]
save_to_clipboard = true

[bell]
animation = "EaseOut"
duration = 0
command = "None"
EOF
}

configure_starship() {
  local target_user target_home bashrc starship_dir starship_config

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  bashrc="${target_home}/.bashrc"
  starship_dir="${target_home}/.config"
  starship_config="${starship_dir}/starship.toml"

  log "Writing Starship config for user ${target_user}..."
  $SUDO install -d -m 0755 -o "$target_user" -g "$target_user" "$starship_dir"
  run_as_target_user "$target_user" "touch \"${bashrc}\""
  cat <<'EOF' | write_file_as_target_user "$target_user" "$starship_config"
add_newline = false

format = "$directory$git_branch$git_status$line_break$character"

[directory]
style = "bold #8aa4bf"
truncate_to_repo = false

[git_branch]
symbol = " "
style = "bold #a7c080"
format = "[$symbol$branch]($style) "

[git_status]
style = "bold #d6996e"
format = "([$all_status$ahead_behind]($style)) "

[character]
success_symbol = "[>](bold #d6dde5)"
error_symbol = "[>](bold #e67e80)"
vimcmd_symbol = "[<](bold #7fbbb3)"
EOF

  if ! grep -Fqx 'export PATH="$PATH:$HOME/.local/bin"' "$bashrc"; then
    printf '\nexport PATH="$PATH:$HOME/.local/bin"\n' | append_file_as_target_user "$target_user" "$bashrc"
  fi

  if ! grep -Fqx 'eval "$(starship init bash)"' "$bashrc"; then
    printf 'eval "$(starship init bash)"\n' | append_file_as_target_user "$target_user" "$bashrc"
  fi
}

configure_google_drive_mount() {
  local target_user target_home local_bin_dir systemd_dir mount_dir launcher_script service_file

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  local_bin_dir="${target_home}/.local/bin"
  systemd_dir="${target_home}/.config/systemd/user"
  mount_dir="${target_home}/GoogleDrive"
  launcher_script="${local_bin_dir}/mount-gdrive"
  service_file="${systemd_dir}/gdrive-rclone.service"

  log "Configuring Google Drive mount helpers for user ${target_user}..."
  $SUDO install -d -m 0755 -o "$target_user" -g "$target_user" "$local_bin_dir"
  $SUDO install -d -m 0755 -o "$target_user" -g "$target_user" "$systemd_dir"
  $SUDO install -d -m 0755 -o "$target_user" -g "$target_user" "$mount_dir"

  cat <<EOF | write_file_as_target_user "$target_user" "$launcher_script"
#!/usr/bin/env bash
set -euo pipefail

RCLONE_BIN="${target_home}/.local/bin/rclone"
if [[ ! -x "\${RCLONE_BIN}" ]]; then
  RCLONE_BIN="rclone"
fi

if ! "\${RCLONE_BIN}" listremotes 2>/dev/null | grep -qx 'gdrive:'; then
  echo "[gdrive] Remote 'gdrive' not configured yet. Run 'rclone config' first."
  exit 0
fi

mkdir -p "${mount_dir}"
exec "\${RCLONE_BIN}" mount gdrive: "${mount_dir}" --vfs-cache-mode writes
EOF
  run_as_target_user "$target_user" "chmod 755 \"${launcher_script}\""

  cat <<EOF | write_file_as_target_user "$target_user" "$service_file"
[Unit]
Description=Mount Google Drive at ${mount_dir}
After=default.target

[Service]
Type=simple
ExecStartPre=/usr/bin/mkdir -p ${mount_dir}
ExecStart=${launcher_script}
ExecStop=/usr/bin/fusermount3 -u ${mount_dir}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

  run_as_target_user "$target_user" "systemctl --user daemon-reload"
  run_as_target_user "$target_user" "systemctl --user enable gdrive-rclone.service"
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
  install_starship
  install_jetbrains_mono_nerd_font
  configure_starship
  configure_alacritty
  configure_google_drive_mount
  install_lazyvim

  # Ensure pipx shims are ready for the current user.
  if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath >/dev/null 2>&1 || true
  fi

  log "Setup completed successfully."
}

main "$@"
