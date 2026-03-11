# Lint scripts with shellcheck
lint:
    shellcheck setup.sh install.sh

# Run a single distro container interactively (e.g. just test docker ubuntu)
docker distro:
    docker compose -f docker/docker-compose.yml run --rm {{distro}}

# Run install.sh --dry-run across ALL supported distros in parallel
docker-all:
    docker compose -f docker/docker-compose.yml --profile test up --abort-on-container-exit
