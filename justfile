set dotenv-load

GITHUB_USER := env("GITHUB_USER", "YOUR_DEFAULT_USERNAME")

default:
    @just --list

# Embed SHA-256 checksum into install.sh (compute with placeholder, then write)
checksum:
    #!/usr/bin/env bash
    set -euo pipefail
    hash=$(sh install.sh --checksum)
    sed -i '' "s/^SELF_CHECKSUM=.*/SELF_CHECKSUM=\"${hash}\"/" install.sh
    echo "Embedded checksum: $hash"

# Lint install.sh with shellcheck
lint:
    shellcheck install.sh

# Test the bootstrap on the local machine (dry-run: installs deps only, no chezmoi init)
test-local:
    sh install.sh --dry-run

# Print the secure one-liner for copy-paste (downloads to tmpfile for checksum verification)
one-liner:
    @echo 'd=$(mktemp -d) && \'
    @echo '  curl -fsSL https://raw.githubusercontent.com/{{GITHUB_USER}}/chezmoi-bootstrap/main/install.sh -o "$d/install.sh" && \'
    @echo '  sh "$d/install.sh" {{GITHUB_USER}} && \'
    @echo '  rm -rf "$d"'

# Export GPG secret keys into gpg-keys/secret-keys.age (age-encrypted)
export-gpg:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p gpg-keys
    tmp=$(mktemp)
    gpg --export-secret-keys --armor > "$tmp"
    echo "Exporting GPG secret keys → gpg-keys/secret-keys.age"
    if [ -n "${AGE_PASSPHRASE:-}" ]; then
        printf '%s' "$AGE_PASSPHRASE" | age -e -p -o gpg-keys/secret-keys.age "$tmp"
    else
        age -e -p -o gpg-keys/secret-keys.age "$tmp"
    fi
    rm -f "$tmp"
    echo "Done. Commit gpg-keys/secret-keys.age to the repo."

# Export SSH private keys into ssh-keys/keys.tar.age (age-encrypted tarball)
export-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p ssh-keys
    keys=()
    for f in ~/.ssh/id_* ~/.ssh/config; do
        [ -f "$f" ] && keys+=("$f")
    done
    if [ ${#keys[@]} -eq 0 ]; then
        echo "No SSH keys found in ~/.ssh/"
        exit 1
    fi
    echo "Bundling: ${keys[*]}"
    tmp=$(mktemp)
    tar cf "$tmp" -C "$HOME/.ssh" $(printf '%s\n' "${keys[@]}" | xargs -n1 basename)
    if [ -n "${AGE_PASSPHRASE:-}" ]; then
        printf '%s' "$AGE_PASSPHRASE" | age -e -p -o ssh-keys/keys.tar.age "$tmp"
    else
        age -e -p -o ssh-keys/keys.tar.age "$tmp"
    fi
    rm -f "$tmp"
    echo "Done. Commit ssh-keys/keys.tar.age to the repo."

# Export both GPG and SSH keys
export-keys: export-gpg export-ssh

# Import GPG keys from the age-encrypted bundle
import-gpg:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Decrypting and importing GPG keys..."
    if [ -n "${AGE_PASSPHRASE:-}" ]; then
        printf '%s' "$AGE_PASSPHRASE" | age -d gpg-keys/secret-keys.age | gpg --import
    else
        age -d gpg-keys/secret-keys.age | gpg --import
    fi
    echo "Done. Run 'gpg --list-secret-keys' to verify."

# Import SSH keys from the age-encrypted bundle
import-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    echo "Decrypting and importing SSH keys..."
    if [ -n "${AGE_PASSPHRASE:-}" ]; then
        printf '%s' "$AGE_PASSPHRASE" | age -d ssh-keys/keys.tar.age | tar xf - -C ~/.ssh
    else
        age -d ssh-keys/keys.tar.age | tar xf - -C ~/.ssh
    fi
    for f in ~/.ssh/id_*; do
        [ -f "$f" ] || continue
        case "$f" in
            *.pub) chmod 644 "$f" ;;
            *)     chmod 600 "$f" ;;
        esac
    done
    chmod 644 ~/.ssh/config 2>/dev/null || true
    echo "Done. Keys installed to ~/.ssh/"

# Import both GPG and SSH keys
import-keys: import-gpg import-ssh

# Run a single distro container interactively (e.g. just test-docker ubuntu)
test-docker distro:
    docker compose -f docker/docker-compose.yml run --rm {{distro}}

# Run install.sh --dry-run across ALL supported distros in parallel
test-docker-all:
    docker compose -f docker/docker-compose.yml --profile test up --abort-on-container-exit

# Tag a new release and push
release version:
    just checksum
    git add install.sh
    git commit -m "release {{version}}"
    git tag -s "v{{version}}" -m "v{{version}}"
    git push origin main --tags
