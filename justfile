set dotenv-load
BOOTSTRAP_REPO := env("BOOTSTRAP_REPO", "f-n1/chezmoi-bootstrap")

default:
    @just --list

# Lint install.sh with shellcheck
lint:
    shellcheck install.sh

# Test the bootstrap on the local machine (dry-run: installs deps only, no chezmoi init)
test-local:
    sh install.sh --dry-run

# Print the one-liner for copy-paste
one-liner GITHUB_USER:
    @echo 'curl -fsSL https://raw.githubusercontent.com/{{BOOTSTRAP_REPO}}/main/install.sh | sh -s -- {{GITHUB_USER}}'

# Run a single distro container interactively (e.g. just test-docker ubuntu)
test-docker distro:
    docker compose -f docker/docker-compose.yml run --rm {{distro}}

# Run install.sh --dry-run across ALL supported distros in parallel
test-docker-all:
    docker compose -f docker/docker-compose.yml --profile test up --abort-on-container-exit

# Tag a new release and push
release version:
    git tag -s "v{{version}}" -m "v{{version}}"
    git push origin main --tags
