# Dotfiles

Personal configuration files managed with [chezmoi](https://chezmoi.io/).

## Installation

```bash
./install.sh
```

Or manually:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply wellcaffeinated/dotfiles
```

## Structure

```
├── dot_config/
│   ├── shell/           # Shared shell config
│   ├── river/           # Window manager
│   └── starship.toml    # Prompt
├── dot_zshrc
├── dot_bashrc
└── install.sh
```

## Usage

```bash
# Update
chezmoi update

# Edit
chezmoi edit ~/.zshrc
chezmoi apply
```
