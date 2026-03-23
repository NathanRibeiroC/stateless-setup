#!/usr/bin/env bash
set -euo pipefail

required_cmds=(
  git
  curl
  wget
  jq
  rg
  tmux
  zsh
  python3
  pipx
  node
  npm
  nvim
  code
  google-chrome
  brave-browser
  bitwarden
  libreoffice
  snap
)

required_snaps=(
  notion-snap-reborn
  obsidian
)

ok_items=()
failed_items=()

add_ok() {
  ok_items+=("$1")
}

add_failed() {
  failed_items+=("$1")
}

for cmd in "${required_cmds[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    add_ok "Command: $cmd"
  else
    add_failed "Command: $cmd"
  fi
done

if command -v mise >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/mise" ]]; then
  add_ok "Command: mise"
else
  add_failed "Command: mise"
fi

for pkg in "${required_snaps[@]}"; do
  if snap list "$pkg" >/dev/null 2>&1; then
    add_ok "Snap: $pkg"
  else
    add_failed "Snap: $pkg"
  fi
done

if [[ -d "${HOME}/.config/nvim" ]]; then
  add_ok "LazyVim config: ${HOME}/.config/nvim"
else
  add_failed "LazyVim config: ${HOME}/.config/nvim"
fi

echo "==== Installed Successfully ===="
if [[ "${#ok_items[@]}" -eq 0 ]]; then
  echo "- None"
else
  for item in "${ok_items[@]}"; do
    echo "- ${item}"
  done
fi

echo
echo "==== Missing / Failed ===="
if [[ "${#failed_items[@]}" -eq 0 ]]; then
  echo "- None"
  echo
  echo "Validation completed successfully."
  exit 0
fi

for item in "${failed_items[@]}"; do
  echo "- ${item}"
done

echo
echo "Validation failed."
exit 1
