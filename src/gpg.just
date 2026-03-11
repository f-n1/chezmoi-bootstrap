GPG_KEYCHAIN := env("HOME") / ".cubby/keychains/gpg"

# Backup GPG keys to ~/.cubby/keychains/gpg/
backup:
    #!/usr/bin/env sh
    set -eu
    mkdir -p "{{GPG_KEYCHAIN}}"
    gpg --export-ownertrust > "{{GPG_KEYCHAIN}}/ownertrust.txt"
    gpg --export --armor > "{{GPG_KEYCHAIN}}/public-keys.asc"
    gpg --export-secret-keys --armor > "{{GPG_KEYCHAIN}}/secret-keys.asc"
    echo "GPG keys backed up to {{GPG_KEYCHAIN}}"

# Restore GPG keys from ~/.cubby/keychains/gpg/
restore:
    #!/usr/bin/env sh
    set -eu
    [ -d "{{GPG_KEYCHAIN}}" ] || { echo "ERROR: {{GPG_KEYCHAIN}} not found"; exit 1; }
    [ -f "{{GPG_KEYCHAIN}}/ownertrust.txt" ] && gpg --import-ownertrust "{{GPG_KEYCHAIN}}/ownertrust.txt"
    [ -f "{{GPG_KEYCHAIN}}/secret-keys.asc" ] && gpg --import "{{GPG_KEYCHAIN}}/secret-keys.asc"
    [ -f "{{GPG_KEYCHAIN}}/public-keys.asc" ] && gpg --import "{{GPG_KEYCHAIN}}/public-keys.asc"
    echo "GPG keys restored from {{GPG_KEYCHAIN}}"
