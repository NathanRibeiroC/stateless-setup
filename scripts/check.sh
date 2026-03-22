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
  code
  google-chrome
  bitwarden
  snap
)

required_snaps=(
  notion-snap-reborn
  obsidian
)

missing=0

for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing command: $cmd"
    missing=1
  else
    echo "OK command: $cmd"
  fi
done

for pkg in "${required_snaps[@]}"; do
  if ! snap list "$pkg" >/dev/null 2>&1; then
    echo "Missing snap: $pkg"
    missing=1
  else
    echo "OK snap: $pkg"
  fi
done

if [[ "$missing" -eq 1 ]]; then
  echo "Validation failed."
  exit 1
fi

echo "Validation completed successfully."
