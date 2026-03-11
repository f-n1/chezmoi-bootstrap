WORKING_DIR := justfile_directory()

# Install prerequisite packages
packages:
    sh {{WORKING_DIR}}/setup.sh packages

# Setup SSH key from $SSH_BOOTSTRAP_KEY (falls back to ssh-agent)
ssh-key:
    sh {{WORKING_DIR}}/setup.sh ssh-key

# Clone or pull keychains repo
pull-keychains GITHUB_USER:
    sh {{WORKING_DIR}}/setup.sh pull-keychains {{GITHUB_USER}}

# Initialize and apply chezmoi dotfiles
chezmoi GITHUB_USER:
    sh {{WORKING_DIR}}/setup.sh chezmoi {{GITHUB_USER}}

# Run full bootstrap (packages + ssh-key + chezmoi)
all GITHUB_USER:
    sh {{WORKING_DIR}}/setup.sh {{GITHUB_USER}}
