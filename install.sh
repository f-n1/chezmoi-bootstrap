#!/bin/sh
# Lightweight installer — clones chezmoi-bootstrap into ~/.bootstrap, then
# hands off to setup.sh which does the real work.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/f-n1/chezmoi-bootstrap/main/install.sh | sh -s -- [OPTIONS] [GITHUB_USERNAME]
set -eu

BOOTSTRAP_DIR="$HOME/.bootstrap"
BOOTSTRAP_REPO_URL="${BOOTSTRAP_REPO_URL:-https://github.com/f-n1/chezmoi-bootstrap.git}"
BOOTSTRAP_BRANCH="${BOOTSTRAP_BRANCH:-main}"
BOOTSTRAP_TARBALL="https://github.com/f-n1/chezmoi-bootstrap/archive/refs/heads/${BOOTSTRAP_BRANCH}.tar.gz"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

if [ -d "$BOOTSTRAP_DIR/.git" ]; then
    info "Updating existing bootstrap repo at $BOOTSTRAP_DIR..."
    git -C "$BOOTSTRAP_DIR" pull --ff-only
elif has git; then
    info "Cloning bootstrap repo into $BOOTSTRAP_DIR..."
    git clone -b "$BOOTSTRAP_BRANCH" "$BOOTSTRAP_REPO_URL" "$BOOTSTRAP_DIR"
elif has curl; then
    info "git not found — downloading tarball into $BOOTSTRAP_DIR..."
    mkdir -p "$BOOTSTRAP_DIR"
    curl -fsSL "$BOOTSTRAP_TARBALL" | tar xz --strip-components=1 -C "$BOOTSTRAP_DIR"
elif has wget; then
    info "git not found — downloading tarball into $BOOTSTRAP_DIR..."
    mkdir -p "$BOOTSTRAP_DIR"
    wget -qO- "$BOOTSTRAP_TARBALL" | tar xz --strip-components=1 -C "$BOOTSTRAP_DIR"
else
    die "git, curl, or wget is required to download the bootstrap repo"
fi

exec sh "$BOOTSTRAP_DIR/setup.sh" "$@"
