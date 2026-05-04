#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

log() {
  printf '[setup:wsl] %s\n' "$1"
}

warn() {
  printf '[setup:wsl][warn] %s\n' "$1" >&2
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

ensure_line_in_file() {
  local target_user="$1"
  local destination="$2"
  local line="$3"

  run_as_target_user "$target_user" "touch \"$destination\""

  if [[ -f "$destination" ]] && grep -Fqx "$line" "$destination"; then
    return
  fi

  printf '%s\n' "$line" | append_file_as_target_user "$target_user" "$destination"
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

is_wsl() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    return 0
  fi

  if [[ -f /proc/sys/kernel/osrelease ]] && grep -qi microsoft /proc/sys/kernel/osrelease; then
    return 0
  fi

  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
    return 0
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
    bash-completion
    build-essential
    ca-certificates
    curl
    fd-find
    fuse3
    git
    gnupg
    jq
    lsb-release
    make
    neovim
    pipx
    python3
    python3-pip
    rclone
    ripgrep
    software-properties-common
    tmux
    tree
    unzip
    wget
    zip
    zsh
  )

  log "Installing WSL development tools..."
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

install_dbeaver() {
  local keyring_file="/usr/share/keyrings/dbeaver.gpg"
  local source_file="/etc/apt/sources.list.d/dbeaver.list"

  log "Configuring DBeaver CE official repository..."
  curl -fsSL https://dbeaver.io/debs/dbeaver.gpg.key | gpg --dearmor | $SUDO tee "$keyring_file" >/dev/null
  $SUDO chmod a+r "$keyring_file"
  echo "deb [signed-by=${keyring_file}] https://dbeaver.io/debs/dbeaver-ce /" | $SUDO tee "$source_file" >/dev/null

  log "Installing DBeaver CE..."
  $SUDO apt-get update -y
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y dbeaver-ce
}

get_target_user() {
  if [[ -n "${WSL_SETUP_TARGET_USER:-}" ]]; then
    printf '%s\n' "${WSL_SETUP_TARGET_USER}"
  elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
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

  run_as_target_user "$target_user" "$install_cmd"
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

  run_as_target_user "$target_user" "$install_cmd"
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

install_codex_skills() {
  local target_user target_home repo_root source_dir skills_dir

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source_dir="${repo_root}/.codex/skills"
  skills_dir="${target_home}/.codex/skills"

  if [[ ! -d "$source_dir" ]]; then
    return
  fi

  log "Installing Codex skills for user ${target_user}..."
  $SUDO install -d -m 0755 -o "$target_user" -g "$target_user" "$skills_dir"
  $SUDO cp -R "${source_dir}/." "$skills_dir/"
  $SUDO chown -R "$target_user:$target_user" "${target_home}/.codex"
}

configure_starship() {
  local target_user target_home bashrc starship_dir starship_config

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  bashrc="${target_home}/.bashrc"
  starship_dir="${target_home}/.config"
  starship_config="${starship_dir}/starship.toml"

  log "Writing Starship and shell config for user ${target_user}..."
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

  ensure_line_in_file "$target_user" "$bashrc" 'export PATH="$HOME/.local/bin:$PATH"'
  ensure_line_in_file "$target_user" "$bashrc" 'export NVM_DIR="$HOME/.nvm"'
  ensure_line_in_file "$target_user" "$bashrc" '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  ensure_line_in_file "$target_user" "$bashrc" '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
  ensure_line_in_file "$target_user" "$bashrc" 'eval "$(starship init bash)"'
}

configure_wsl_conf() {
  local target_user="$1"
  local tmp_file

  log "Writing /etc/wsl.conf with systemd and default user..."
  if [[ -f /etc/wsl.conf ]]; then
    warn "Overwriting existing /etc/wsl.conf with setup-stateless defaults."
  fi

  tmp_file="$(mktemp)"
  cat > "$tmp_file" <<EOF
[boot]
systemd=true

[user]
default=${target_user}
EOF

  $SUDO install -m 0644 "$tmp_file" /etc/wsl.conf
  rm -f "$tmp_file"
}

install_lazyvim() {
  local target_user target_home nvim_config nvim_data backup_suffix

  target_user="$(get_target_user)"
  target_home="$(get_target_home "$target_user")"
  nvim_config="${target_home}/.config/nvim"
  nvim_data="${target_home}/.local/share/nvim"
  backup_suffix="setup-stateless-backup"

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
  local target_user

  require_cmd apt-get
  require_cmd dpkg

  if ! is_ubuntu; then
    echo "This installer supports Ubuntu systems only."
    exit 1
  fi

  if ! is_wsl; then
    echo "This installer is meant for Ubuntu running inside WSL."
    exit 1
  fi

  target_user="$(get_target_user)"
  if [[ "$target_user" == "root" ]]; then
    echo "Use a non-root WSL user or set WSL_SETUP_TARGET_USER before running this installer."
    exit 1
  fi

  log "Starting Ubuntu WSL stateless setup for ${target_user}..."
  apt_update_if_needed
  install_packages
  install_dbeaver
  install_node
  install_mise
  install_starship
  install_codex_skills
  configure_starship
  configure_wsl_conf "$target_user"
  install_lazyvim

  if command -v pipx >/dev/null 2>&1; then
    run_as_target_user "$target_user" "pipx ensurepath >/dev/null 2>&1 || true"
  fi

  log "WSL setup completed successfully."
  log "Run 'wsl.exe --shutdown' from Windows PowerShell once the install finishes to apply /etc/wsl.conf changes."
}

main "$@"
