#!/bin/sh
# Lightweight installer — clones cubby into ~/.cubby, then
# hands off to setup.sh which does the real work.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/f-n1/cubby/main/install.sh | sh -s -- [OPTIONS] [GITHUB_USERNAME]
set -eu

BOOTSTRAP_DIR="$HOME/.cubby/bootstrap"
BOOTSTRAP_REPO_URL="${BOOTSTRAP_REPO_URL:-https://github.com/f-n1/cubby.git}"
BOOTSTRAP_BRANCH="${BOOTSTRAP_BRANCH:-main}"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

mkdir -p "$BOOTSTRAP_DIR"

if has git; then
    if [ -d "$BOOTSTRAP_DIR/.git" ]; then
        info "Updating existing bootstrap repo at $BOOTSTRAP_DIR..."
        git -C "$BOOTSTRAP_DIR" pull --ff-only
    else
        info "Cloning bootstrap repo into $BOOTSTRAP_DIR..."
        git clone -b "$BOOTSTRAP_BRANCH" "$BOOTSTRAP_REPO_URL" "$BOOTSTRAP_DIR"
    fi
else
    die "git is required to download the bootstrap repo"
fi

exec sh "$BOOTSTRAP_DIR/setup.sh" "$@"
