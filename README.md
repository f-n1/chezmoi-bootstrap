# chezmoi-bootstrap

Secure one-liner to install prerequisites and initialize [chezmoi](https://www.chezmoi.io/) on a fresh machine.

Supports **macOS** (Homebrew) and **Linux** (apt, dnf, pacman, apk).

## What it installs

| Package   | Purpose                              |
|-----------|--------------------------------------|
| git       | Clone dotfiles repo                  |
| gnupg     | Decrypt chezmoi-encrypted secrets    |
| age       | Decrypt GPG key bundle               |
| openssh   | SSH access after bootstrap           |
| chezmoi   | Dotfile manager                      |

## Secure one-liner

Download, verify checksum, then run (replace `YOUR_GITHUB_USER`):

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/bootstrap/main/install.sh -o /tmp/cm-bootstrap.sh && \
  curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/bootstrap/main/checksums.sha256 -o /tmp/cm-checksums.sha256 && \
  (cd /tmp && shasum -a 256 -c cm-checksums.sha256) && \
  sh /tmp/cm-bootstrap.sh YOUR_GITHUB_USER && \
  rm -f /tmp/cm-bootstrap.sh /tmp/cm-checksums.sha256
```

Or generate it with `just one-liner` after setting `GITHUB_USER` in `.env`.

## Usage

```bash
# Full bootstrap (installs deps + chezmoi init)
sh install.sh YOUR_GITHUB_USER

# Dry run — print what would happen without changing anything
sh install.sh --dry-run

# Use environment variable instead of argument
GITHUB_USER=you sh install.sh
```

## Development

Requires [just](https://github.com/casey/just).

```bash
just              # list available recipes
just checksum     # regenerate checksums.sha256
just lint         # shellcheck install.sh
just test-local   # dry-run on this machine
just one-liner    # print the secure one-liner
just release 1.0  # tag and push a release
```

## Security model

- The bootstrap script contains **no secrets** — it only installs tools.
- The initial dotfiles clone uses **HTTPS** (no SSH key required).
- After chezmoi applies, a `run_after` script switches the remote to **SSH**.
- The script is verified via **SHA-256 checksum** before execution.
