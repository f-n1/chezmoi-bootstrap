set dotenv-load
BOOTSTRAP_REPO := env("BOOTSTRAP_REPO", "f-n1/cubby")
TIMESTAMP := `date +%Y%m%d_%H%M%S`
CUBBY_HOME := "{{$HOME/.cubby}}"
GPG_KEYCHAIN := CUBBY_HOME +"/keychains/gpg"

default:
    @just --list

# Lint scripts with shellcheck
lint:
    shellcheck setup.sh install.sh

# Test the bootstrap on the local machine (dry-run: installs deps only, no chezmoi init)
test-local:
    sh setup.sh --dry-run

# Print the one-liner for copy-paste
one-liner GITHUB_USER:
    @echo 'curl -fsSL https://raw.githubusercontent.com/{{BOOTSTRAP_REPO}}/main/install.sh?t={{TIMESTAMP}} | sh -s -- {{GITHUB_USER}}'

# Run install.sh on a remote SSH host (e.g. just install user@host)
install target *ARGS:
    ssh -A {{target}} 'curl -fsSL "https://raw.githubusercontent.com/{{BOOTSTRAP_REPO}}/main/install.sh?t={{TIMESTAMP}}" | sh -s -- {{ARGS}}'

# Run a single distro container interactively (e.g. just test-docker ubuntu)
test-docker distro:
    docker compose -f docker/docker-compose.yml run --rm {{distro}}

# Run install.sh --dry-run across ALL supported distros in parallel
test-docker-all:
    docker compose -f docker/docker-compose.yml --profile test up --abort-on-container-exit

# Backup GPG keys to ~/.cubby/keychains/gpg/
backup-gpg:
    #!/usr/bin/env sh
    set -eu
    mkdir -p "{{GPG_KEYCHAIN}}"
    gpg --export-ownertrust > "{{GPG_KEYCHAIN}}/ownertrust.txt"
    gpg --export --armor > "{{GPG_KEYCHAIN}}/public-keys.asc"
    gpg --export-secret-keys --armor > "{{GPG_KEYCHAIN}}/secret-keys.asc"
    echo "PGP keys backed up to {{GPG_KEYCHAIN}}"

# Restore GPG keys from ~/.cubby/keychains/gpg/
restore-gpg:
    #!/usr/bin/env sh
    set -eu
    [ -d "{{GPG_KEYCHAIN}}" ] || { echo "ERROR: {{GPG_KEYCHAIN}} not found"; exit 1; }
    [ -f "{{GPG_KEYCHAIN}}/ownertrust.txt" ] && gpg --import-ownertrust "{{GPG_KEYCHAIN}}/ownertrust.txt"
    [ -f "{{GPG_KEYCHAIN}}/secret-keys.asc" ] && gpg --import "{{GPG_KEYCHAIN}}/secret-keys.asc"
    [ -f "{{GPG_KEYCHAIN}}/public-keys.asc" ] && gpg --import "{{GPG_KEYCHAIN}}/public-keys.asc"
    echo "PGP keys restored from {{GPG_KEYCHAIN}}"

# Commit all current changes
commit:
    git add -A
    git commit -m "update {{TIMESTAMP}}"

# Tag a new release and push
release version:
    sed -i'' -e 's/^VERSION=".*"/VERSION="{{version}}"/' setup.sh
    git add setup.sh
    git commit -m "release v{{version}}"
    git tag -s "v{{version}}" -m "v{{version}}"
    git push origin main --tags
