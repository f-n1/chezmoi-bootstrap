set dotenv-load
BOOTSTRAP_REPO := env("BOOTSTRAP_REPO", "f-n1/chezmoi-bootstrap")
TIMESTAMP := `date +%Y%m%d_%H%M%S`

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

# Run a single distro container interactively (e.g. just test-docker ubuntu)
test-docker distro:
    docker compose -f docker/docker-compose.yml run --rm {{distro}}

# Run install.sh --dry-run across ALL supported distros in parallel
test-docker-all:
    docker compose -f docker/docker-compose.yml --profile test up --abort-on-container-exit

# Tag a new release and push
release version:
    sed -i'' -e 's/^VERSION=".*"/VERSION="{{version}}"/' setup.sh
    git add setup.sh
    git commit -m "release v{{version}}"
    git tag -s "v{{version}}" -m "v{{version}}"
    git push origin main --tags
