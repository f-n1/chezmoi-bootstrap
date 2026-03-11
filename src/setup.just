# Install prerequisite packages
packages:
    sh setup.sh packages

# Setup SSH key from $SSH_BOOTSTRAP_KEY (falls back to ssh-agent)
ssh-key:
    sh setup.sh ssh-key

# Clone or pull keychains repo
pull-keychains GITHUB_USER:
    sh setup.sh pull-keychains {{GITHUB_USER}}

# Initialize and apply chezmoi dotfiles
chezmoi GITHUB_USER:
    sh setup.sh chezmoi {{GITHUB_USER}}

# Run full bootstrap (packages + ssh-key + chezmoi)
all GITHUB_USER:
    sh setup.sh {{GITHUB_USER}}
