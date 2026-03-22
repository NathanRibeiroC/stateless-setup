# setup-stateless

Stateless Linux bootstrap focused on speed and repeatability.

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

## Local usage

```bash
bash install.sh
bash scripts/check.sh
```

## Notes

- Only Ubuntu is currently implemented.
- Run with a user that has `sudo` access.
- Script is idempotent and safe to re-run.
