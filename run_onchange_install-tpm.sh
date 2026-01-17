#!/bin/bash
# Install TPM (Tmux Plugin Manager) if tmux and git are installed

# Exit silently if tmux is not installed
command -v tmux >/dev/null 2>&1 || exit 0

# Exit silently if git is not installed
command -v git >/dev/null 2>&1 || exit 0

TPM_DIR="$HOME/.tmux/plugins/tpm"

# Exit silently if TPM is already installed
[ -d "$TPM_DIR" ] && exit 0

# Install TPM
echo "Installing TPM (Tmux Plugin Manager)..."
git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"

echo "TPM installed. Press prefix + I inside tmux to install plugins."
