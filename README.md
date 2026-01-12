# Dotfiles

Personal configuration files managed with [chezmoi](https://chezmoi.io/).

## Installation

See [chezmoi.io](https://chezmoi.io/) for installation.

```bash
chezmoi init --apply wellcaffeinated/dotfiles
```

Note: `install.sh` is for devcontainer setup.

## Structure

```
├── dot_config/
│   ├── shell/           # Shared shell config
│   ├── river/           # Window manager
│   └── starship.toml    # Prompt
├── dot_zshrc
├── dot_bashrc
└── dot_tmux.conf        # Tmux config
```

## Usage

```bash
# Update
chezmoi update

# Edit
chezmoi edit ~/.zshrc
chezmoi apply
```
