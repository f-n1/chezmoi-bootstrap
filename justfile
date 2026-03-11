set dotenv-load
TIMESTAMP := `date +%Y%m%d_%H%M%S`
INSTALL_SCRIPT := "https://raw.githubusercontent.com/f-n1/cubby/main/install.sh?t=" + TIMESTAMP
mod setup 'src/setup.just'
mod test 'src/test.just'
mod gpg 'src/gpg.just'

default:
    @just --list --list-submodules

# Print the one-liner for copy-paste
one-liner GITHUB_USER:
    @echo 'curl -fsSL {{INSTALL_SCRIPT}} | sh -s -- {{GITHUB_USER}}'

# Run install.sh on a remote SSH host (e.g. just install user@host)
install target *ARGS:
    ssh -A {{target}} 'curl -fsSL {{INSTALL_SCRIPT}} | sh -s -- {{ARGS}}'

# Commit all current changes
commit:
    git add -A
    git commit -m "update {{TIMESTAMP}}"

# Tag a new release and push
release version:
    sed -i '' 's/^VERSION=".*"/VERSION="{{version}}"/' bin/bootstrap.sh
    git add bin/bootstrap.sh
    git commit -m "release v{{version}}"
    git tag -s "v{{version}}" -m "v{{version}}"
    git push origin main --tags
