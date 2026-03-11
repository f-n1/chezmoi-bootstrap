WORKING_DIR := justfile_directory()

# Lint scripts with shellcheck
lint:
    shellcheck {{WORKING_DIR}}/bin/bootstrap.sh {{WORKING_DIR}}/install.sh

# Run a single distro container interactively (e.g. just test docker ubuntu)
docker distro:
    docker compose -f {{WORKING_DIR}}/docker/docker-compose.yml run --rm {{distro}}

# Run install.sh --dry-run across ALL supported distros in parallel
docker-all:
    docker compose -f {{WORKING_DIR}}/docker/docker-compose.yml --profile test up --abort-on-container-exit

build distro:
    docker build -t cubby:{{distro}} -f {{WORKING_DIR}}/img/{{distro}}/Dockerfile {{WORKING_DIR}}/img/{{distro}}