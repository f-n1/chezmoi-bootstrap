#!/bin/sh
# Secure chezmoi bootstrap — installs prerequisites and initializes dotfiles.
# Supports macOS (Homebrew) and Linux (apt, dnf, pacman, apk).
#
# Usage:
#   sh setup.sh [--dry-run] [COMMAND] [GITHUB_USERNAME]
#
# Commands:
#   all             Run full bootstrap (default)
#   packages        Install prerequisite packages
#   ssh-key         Setup SSH key from SSH_BOOTSTRAP_KEY
#   pull-keychains  Clone/pull keychains repo
#   chezmoi         Initialize and apply chezmoi dotfiles
set -eu

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

VERSION="1.20"
GITHUB_USER=""
COMMAND="all"
DRY_RUN=0
CUBBY_HOME="$HOME/.cubby"
BOOTSTRAP_KEY="$CUBBY_HOME/id_bootstrap"
MACOS_PKGS="git gnupg age openssh gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_ALPINE="git gnupg age openssh-client curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_ARCH="git gnupg age openssh curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_RPM="git gnupg2 openssh-clients curl gopass chezmoi vim fish mc htop iftop bmon age"
LINUX_PKGS_DEBIAN="git gnupg age openssh-client curl gopass chezmoi vim fish mc htop iftop bmon"

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

    local pkgs="git gnupg age openssh gopass chezmoi vim fish mc htop iftop bmon"
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
            run $sudo_cmd apt-get install -y -qq $LINUX_PKGS_DEBIAN
            ;;
        centos|rhel|rocky|alma|ultramarine|fedora)
            info "Installing packages via dnf..."
            run $sudo_cmd dnf install -y $LINUX_PKGS_RPM
            ;;
        arch|manjaro|endeavouros)
            info "Installing packages via pacman..."
            run $sudo_cmd pacman -Sy --noconfirm --needed $LINUX_PKGS_ARCH
            ;;
        alpine)
            info "Installing packages via apk..."
            run $sudo_cmd apk add --no-cache $LINUX_PKGS_ALPINE
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
# SSH key setup
# ---------------------------------------------------------------------------


validate_ssh_key() {
    keyfile="$1"
    if ssh-keygen -l -f "$keyfile" >/dev/null 2>&1; then
        return 0
    fi
    head -1 "$keyfile" | grep -q "BEGIN.*PRIVATE KEY"
}

ssh_key_info() {
    keyfile="$1"
    fingerprint=$(ssh-keygen -l -f "$keyfile" 2>/dev/null | cut -d' ' -f1-2)
    if [ -n "$fingerprint" ]; then
        echo "$fingerprint"
    else
        echo "[encrypted key]"
    fi
}

setup_ssh_key() {
    if [ -z "${SSH_BOOTSTRAP_KEY:-}" ]; then
        info "No SSH_BOOTSTRAP_KEY set — using ssh-agent for authentication."
        return 0
    fi

    mkdir -p "$(dirname "$BOOTSTRAP_KEY")"
    chmod 700 "$(dirname "$BOOTSTRAP_KEY")"

    info "Using SSH key from SSH_BOOTSTRAP_KEY environment variable."
    tmp_key="$(mktemp)"
    printf '%s\n' "$SSH_BOOTSTRAP_KEY" | base64 -d > "$tmp_key"
    chmod 600 "$tmp_key"

    if ! validate_ssh_key "$tmp_key"; then
        rm -f "$tmp_key"
        die "SSH_BOOTSTRAP_KEY is not a valid SSH private key"
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    mv "$tmp_key" "$BOOTSTRAP_KEY"
    info "Saved bootstrap key to $BOOTSTRAP_KEY ($(ssh_key_info "$BOOTSTRAP_KEY"))"
}

# ---------------------------------------------------------------------------
# Keychains
# ---------------------------------------------------------------------------

pull_keychains() {
    if [ -z "$GITHUB_USER" ]; then
        warn "No GITHUB_USER set — skipping keychains pull."
        return 0
    fi

    keychains_dir="$CUBBY_HOME/keychains"
    keychains_repo="git@github.com:${GITHUB_USER}/keychains.git"

    git_ssh=""
    if [ -f "$BOOTSTRAP_KEY" ]; then
        git_ssh="ssh -i $BOOTSTRAP_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    fi

    if [ -d "$keychains_dir/.git" ]; then
        info "Updating keychains at $keychains_dir..."
        run env ${git_ssh:+GIT_SSH_COMMAND="$git_ssh"} git -C "$keychains_dir" pull --ff-only
    else
        info "Cloning keychains from $keychains_repo..."
        mkdir -p "$keychains_dir"
        run env ${git_ssh:+GIT_SSH_COMMAND="$git_ssh"} git clone "$keychains_repo" "$keychains_dir"
    fi
}

# ---------------------------------------------------------------------------
# chezmoi
# ---------------------------------------------------------------------------

check_chezmoi() {
    if has chezmoi; then
        info "chezmoi found: $(chezmoi --version)"
        return 0
    fi

    die "chezmoi is not installed. Install it from https://www.chezmoi.io/install/"
}

init_chezmoi() {
    if [ -z "$GITHUB_USER" ]; then
        warn "No GITHUB_USER set — skipping chezmoi init."
        warn "Run manually: chezmoi init --apply --ssh <user>"
        return 0
    fi

    repo="git@github.com:${GITHUB_USER}/dotfiles.git"

    git_ssh=""
    if [ -f "$BOOTSTRAP_KEY" ]; then
        git_ssh="ssh -i $BOOTSTRAP_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    fi

    chezmoi_source="$(chezmoi source-path 2>/dev/null || true)"
    if [ -n "$chezmoi_source" ] && [ -d "$chezmoi_source/.git" ]; then
        info "Detected chezmoi source already exists — pulling latest..."
        run env ${git_ssh:+GIT_SSH_COMMAND="$git_ssh"} git -C "$chezmoi_source" pull --ff-only
    else
        info "Initializing chezmoi for $repo..."
        run env ${git_ssh:+GIT_SSH_COMMAND="$git_ssh"} chezmoi init "$repo"
    fi

    info "Applying dotfiles (skipping encrypted files)..."
    run chezmoi apply --exclude encrypted
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --help|-h)
                printf 'Usage: %s [--dry-run] [COMMAND] [GITHUB_USERNAME]\n' "$0"
                printf 'Commands: all (default), packages, ssh-key, chezmoi\n'
                exit 0
                ;;
            all|packages|ssh-key|pull-keychains|chezmoi)
                COMMAND="$1"
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

    info "cubby v${VERSION} — install prerequisites and initialize dotfiles"
    info "Target: $OS_TYPE${DISTRO:+ ($DISTRO)}"
    [ "$DRY_RUN" -eq 1 ] && info "Dry-run mode — no changes will be made"

    case "$COMMAND" in
        packages)
            install_packages
            ;;
        pull-keychains)
            setup_ssh_key
            pull_keychains
            ;;
        chezmoi)
            setup_ssh_key
            check_chezmoi
            init_chezmoi
            ;;
        all)
            setup_ssh_key
            install_packages
            pull_keychains
            check_chezmoi
            init_chezmoi
            info "Bootstrap complete."
            if has chezmoi; then
                info "chezmoi version: $(chezmoi --version)"
                info "chezmoi doctor:  chezmoi doctor"
            fi
            ;;
    esac
}

main "$@"
