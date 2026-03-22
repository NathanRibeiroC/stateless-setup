# setup-stateless

Stateless Linux bootstrap focused on speed and repeatability.

## Prerequisites

Before running the installer, make sure your GitHub access is configured from the terminal:

1. Configure an SSH key and add it to GitHub.
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
gh auth login
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)-$(date +%F)"
```
2. Configure a GPG key and add it to GitHub for signed commits.
```bash
gpg --full-generate-key
gpg --list-secret-keys --keyid-format LONG
gpg --armor --export <YOUR_KEY_ID> | gh gpg-key add -
```
3. Ensure GitHub CLI authentication is active.
```bash
gh auth status
```

## One-liner (run directly from GitHub)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NathanRibeiroC/setup-stateless/main/install.sh)
```

## Current support

- `ubuntu` (implemented)
- `fedora` (planned)
- `gentoo` (planned)

## Installers layout

- `install.sh` (distribution dispatcher)
- `installers/ubuntu.sh` (Ubuntu implementation)
- `installers/fedora.sh` (future)
- `installers/gentoo.sh` (future)

## Installed tools (Ubuntu)

- Core CLI: `curl`, `wget`, `git`, `jq`, `ripgrep`, `fd-find`, `tmux`, `tree`, `zsh`, `xclip`
- Build/tooling: `build-essential`, `make`, `zip`, `unzip`
- Python: `python3`, `python3-pip`, `pipx`
- Base system packages: `ca-certificates`, `gnupg`, `lsb-release`, `software-properties-common`, `snapd`
- Desktop apps: `code`, `google-chrome-stable`, `bitwarden`, `notion-snap-reborn` (snap), `obsidian` (snap)

## Local usage

```bash
bash install.sh
bash scripts/check.sh
```

## Notes

- Only Ubuntu is currently implemented.
- Run with a user that has `sudo` access.
- Script is idempotent and safe to re-run.
