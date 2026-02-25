set dotenv-load

github_user := env("GITHUB_USER", "YOUR_DEFAULT_USERNAME")

default:
    @just --list

# Regenerate checksums.sha256 after editing install.sh
checksum:
    shasum -a 256 install.sh > checksums.sha256
    @echo "Updated checksums.sha256"

# Lint install.sh with shellcheck
lint:
    shellcheck install.sh

# Test the bootstrap on the local machine (dry-run: installs deps only, no chezmoi init)
test-local:
    sh install.sh --dry-run

# Print the secure one-liner for copy-paste
one-liner:
    @echo 'curl -fsSL https://raw.githubusercontent.com/{{github_user}}/bootstrap/main/install.sh -o /tmp/cm-bootstrap.sh && \'
    @echo '  curl -fsSL https://raw.githubusercontent.com/{{github_user}}/bootstrap/main/checksums.sha256 -o /tmp/cm-checksums.sha256 && \'
    @echo '  (cd /tmp && shasum -a 256 -c cm-checksums.sha256) && \'
    @echo '  sh /tmp/cm-bootstrap.sh && \'
    @echo '  rm -f /tmp/cm-bootstrap.sh /tmp/cm-checksums.sha256'

# Tag a new release and push
release version:
    just checksum
    git add install.sh checksums.sha256
    git commit -m "release {{version}}"
    git tag -s "v{{version}}" -m "v{{version}}"
    git push origin main --tags
