# cubby

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

Download to a temp file so the embedded checksum can be verified, then run (replace `YOUR_GITHUB_USER`):

```bash
d=$(mktemp -d) && \
  curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/cubby/main/install.sh -o "$d/install.sh" && \
  sh "$d/install.sh" YOUR_GITHUB_USER && \
  rm -rf "$d"
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

## Key management

Export your GPG and SSH keys (encrypted with age) for storage in this repo:

```bash
just export-gpg     # GPG secret keys → gpg-keys/secret-keys.age
just export-ssh     # SSH private keys → ssh-keys/keys.tar.age
just export-keys    # both at once
```

Import keys locally (outside the bootstrap flow):

```bash
just import-gpg     # decrypt and import GPG keys
just import-ssh     # decrypt and install SSH keys to ~/.ssh/
just import-keys    # both at once
```

During bootstrap, `install.sh` automatically downloads and imports both bundles from this repo (prompting for the age passphrase).

## Development

Requires [just](https://github.com/casey/just).

```bash
just              # list available recipes
just checksum     # embed SHA-256 into install.sh
just lint         # shellcheck install.sh
just test-local   # dry-run on this machine
just one-liner    # print the secure one-liner
just export-keys  # export GPG + SSH keys
just release 1.0  # tag and push a release
```

## Security model

- GPG and SSH private keys are **encrypted with age** (passphrase-based) before storage.
- The age passphrase is the **single root secret** — memorized, never stored digitally.
- The bootstrap script **self-verifies** via an embedded SHA-256 checksum.
- The initial dotfiles clone uses **HTTPS** (no SSH key needed to start).
- After chezmoi applies, a `run_after` script switches the remote to **SSH**.
