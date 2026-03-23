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

If `curl` is not installed yet (fresh Ubuntu), run:

```bash
sudo apt update && sudo apt install -y curl
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

- Core CLI: `curl`, `wget`, `git`, `jq`, `ripgrep`, `fd-find`, `tmux`, `tree`, `zsh`, `xclip`, `nvim`
- Build/tooling: `build-essential`, `make`, `zip`, `unzip`
- Python: `python3`, `python3-pip`, `pipx`
- JavaScript/Node: `nvm` + latest `node` and `npm`
- Runtime manager: `mise` (installed to `~/.local/bin/mise`)
- Base system packages: `ca-certificates`, `gnupg`, `lsb-release`, `software-properties-common`, `snapd`
- Desktop apps: `code`, `google-chrome-stable`, `brave-browser`, `bitwarden`, `libreoffice`, `jetbrains-toolbox`, `notion-snap-reborn` (snap), `obsidian` (snap)
- Editor setup: LazyVim starter in `~/.config/nvim` (if no existing Neovim config is present)

## Local usage

```bash
bash install.sh
bash scripts/check.sh
```

## Post-install validation

Run the full validation:

```bash
bash scripts/check.sh
```

Run install + validation in a single command:

```bash
bash install.sh && bash scripts/check.sh
```

Show only failed/missing checks:

```bash
bash scripts/check.sh 2>&1 | rg "Missing|failed" -i
```

## Notes

- Only Ubuntu is currently implemented.
- Run with a user that has `sudo` access.
- Script is idempotent and safe to re-run.

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE).
