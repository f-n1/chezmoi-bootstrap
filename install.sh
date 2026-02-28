#!/bin/sh
# Secure chezmoi bootstrap — installs prerequisites and initializes dotfiles.
# Supports macOS (Homebrew) and Linux (apt, dnf, pacman, apk).
#
# Usage:
#   sh install.sh [--dry-run] [--repo REPO] [GITHUB_USERNAME]
set -eu

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CHEZMOI_REPO=""
GITHUB_USER=""
DRY_RUN=0
MACOS_PKGS="git gnupg age openssh gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS="git gnupg2 age openssh-clients curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_ALPINE="git gnupg age openssh-client curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_ARCH="git gnupg age openssh curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_CENTOS="git gnupg2 openssh-clients curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_FEDORA="git gnupg2 openssh-clients curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_MANJARO="git gnupg age openssh curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_RASPBIAN="git gnupg age openssh-client curl gopass chezmoi vim fish mc htop iftop bmon"
LINUX_PKGS_UBUNTU="git gnupg age openssh-client curl gopass chezmoi vim fish mc htop iftop bmon"

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
            run $sudo_cmd apt-get install -y -qq $LINUX_PKGS_UBUNTU
            ;;
        fedora)
            info "Installing packages via dnf..."
            run $sudo_cmd dnf install -y $LINUX_PKGS_FEDORA
            ;;
        centos|rhel|rocky|alma)
            info "Installing packages via dnf..."
            run $sudo_cmd dnf install -y $LINUX_PKGS_CENTOS
            warn "age may not be in default repos — install manually if missing"
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

BOOTSTRAP_KEY="$HOME/.ssh/id_chezmoi_bootstrap"

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

import_ssh_key() {
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [ -f "$BOOTSTRAP_KEY" ]; then
        if validate_ssh_key "$BOOTSTRAP_KEY"; then
            info "Valid bootstrap SSH key exists at $BOOTSTRAP_KEY ($(ssh_key_info "$BOOTSTRAP_KEY"))"
            printf '    Replace it? [y/N] '
            read -r answer < /dev/tty
            case "$answer" in
                y|Y|yes|YES) ;;
                *) info "Keeping existing key."; return 0 ;;
            esac
        else
            warn "Existing $BOOTSTRAP_KEY is not a valid SSH key — replacing."
        fi
    fi

    info "Paste your SSH private key below, then press Enter and Ctrl-D (Ctrl-C to abort):"
    tmp_key="$(mktemp)"
    cat < /dev/tty > "$tmp_key"

    chmod 600 "$tmp_key"
    if ! validate_ssh_key "$tmp_key"; then
        rm -f "$tmp_key"
        die "Input is not a valid SSH private key"
    fi

    mv "$tmp_key" "$BOOTSTRAP_KEY"
    info "Saved bootstrap key to $BOOTSTRAP_KEY ($(ssh_key_info "$BOOTSTRAP_KEY"))"
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
    repo="${CHEZMOI_REPO:-${GITHUB_USER}}"
    if [ -z "$repo" ]; then
        warn "No CHEZMOI_REPO or GITHUB_USER set — skipping chezmoi init."
        warn "Run manually: chezmoi init --apply <repo>"
        return 0
    fi

    info "Initializing chezmoi for $repo..."
    if [ -f "$BOOTSTRAP_KEY" ]; then
        GIT_SSH_COMMAND="ssh -i $BOOTSTRAP_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
            run chezmoi init --ssh --apply "$repo"
    else
        run chezmoi init --ssh --apply "$repo"
    fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --repo)
                shift
                [ $# -gt 0 ] || die "--repo requires an argument"
                CHEZMOI_REPO="$1"
                ;;
            --repo=*) CHEZMOI_REPO="${1#--repo=}" ;;
            --help|-h)
                printf 'Usage: %s [--dry-run] [--repo REPO] [GITHUB_USERNAME]\n' "$0"
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
    import_ssh_key
    check_chezmoi
    init_chezmoi

    info "Bootstrap complete."
    if has chezmoi; then
        info "chezmoi version: $(chezmoi --version)"
        info "chezmoi doctor:  chezmoi doctor"
    fi
}

main "$@"
