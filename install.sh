#!/bin/sh
# Secure chezmoi bootstrap — installs prerequisites and initializes dotfiles.
# Supports macOS (Homebrew) and Linux (apt, dnf, pacman, apk).
#
# Usage:
#   sh install.sh [--dry-run] [GITHUB_USERNAME]
#   GITHUB_USER=you sh install.sh
set -eu

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CHEZMOI_BIN_DIR="${CHEZMOI_BIN_DIR:-$HOME/.local/bin}"
GITHUB_USER="${GITHUB_USER:-}"
DRY_RUN=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '\033[0;90m[dry-run]\033[0m %s\n' "$*"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------

detect_os() {
    OS="$(uname -s)"
    case "$OS" in
        Darwin) OS_TYPE="macos" ;;
        Linux)  OS_TYPE="linux" ;;
        *)      die "Unsupported OS: $OS" ;;
    esac

    DISTRO=""
    if [ "$OS_TYPE" = "linux" ] && [ -f /etc/os-release ]; then
        DISTRO="$(. /etc/os-release && echo "${ID:-unknown}")"
    fi
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------

need_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "sudo"
    fi
}

install_macos() {
    if ! has brew; then
        info "Installing Homebrew..."
        run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    local pkgs="git gnupg age openssh"
    info "Installing packages via Homebrew: $pkgs"
    for pkg in $pkgs; do
        if brew list --formula "$pkg" >/dev/null 2>&1; then
            info "  $pkg — already installed"
        else
            run brew install "$pkg"
        fi
    done
}

install_linux() {
    local sudo_cmd
    sudo_cmd="$(need_sudo)"

    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint|raspbian)
            info "Installing packages via apt..."
            run $sudo_cmd apt-get update -qq
            run $sudo_cmd apt-get install -y -qq git gnupg age openssh-client curl
            ;;
        fedora)
            info "Installing packages via dnf..."
            run $sudo_cmd dnf install -y git gnupg2 age openssh-clients curl
            ;;
        centos|rhel|rocky|alma)
            info "Installing packages via dnf..."
            run $sudo_cmd dnf install -y git gnupg2 openssh-clients curl
            warn "age may not be in default repos — install manually if missing"
            ;;
        arch|manjaro|endeavouros)
            info "Installing packages via pacman..."
            run $sudo_cmd pacman -Sy --noconfirm --needed git gnupg age openssh curl
            ;;
        alpine)
            info "Installing packages via apk..."
            run $sudo_cmd apk add --no-cache git gnupg age openssh-client curl
            ;;
        *)
            die "Unsupported Linux distribution: $DISTRO"
            ;;
    esac
}

install_packages() {
    case "$OS_TYPE" in
        macos) install_macos ;;
        linux) install_linux ;;
    esac
}

# ---------------------------------------------------------------------------
# chezmoi
# ---------------------------------------------------------------------------

install_chezmoi() {
    if has chezmoi; then
        info "chezmoi already installed: $(chezmoi --version)"
        return 0
    fi

    info "Installing chezmoi to $CHEZMOI_BIN_DIR..."
    mkdir -p "$CHEZMOI_BIN_DIR"
    run sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$CHEZMOI_BIN_DIR"

    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$CHEZMOI_BIN_DIR"; then
        export PATH="$CHEZMOI_BIN_DIR:$PATH"
    fi
}

init_chezmoi() {
    if [ -z "$GITHUB_USER" ]; then
        warn "No GITHUB_USER set — skipping chezmoi init."
        warn "Run manually: chezmoi init --apply YOUR_GITHUB_USER"
        return 0
    fi

    info "Initializing chezmoi for $GITHUB_USER..."
    run chezmoi init --apply "$GITHUB_USER"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --help|-h)
                printf 'Usage: %s [--dry-run] [GITHUB_USERNAME]\n' "$0"
                printf 'Environment: GITHUB_USER, CHEZMOI_BIN_DIR\n'
                exit 0
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                GITHUB_USER="$1"
                ;;
        esac
        shift
    done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    parse_args "$@"
    detect_os

    info "Chezmoi bootstrap — $OS_TYPE${DISTRO:+ ($DISTRO)}"
    [ "$DRY_RUN" -eq 1 ] && info "Dry-run mode — no changes will be made"

    install_packages
    install_chezmoi
    init_chezmoi

    info "Bootstrap complete."
    if has chezmoi; then
        info "chezmoi version: $(chezmoi --version)"
        info "chezmoi doctor:  chezmoi doctor"
    fi
}

main "$@"
