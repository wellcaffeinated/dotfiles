# Dotfiles

Personal configuration files managed with [chezmoi](https://chezmoi.io/).

## Overview

This repository contains cross-platform shell configurations and window manager setups optimized for daily development work.

### Key Features

- **Cross-shell compatibility**: Shared configuration for bash and zsh
- **Plugin management**: Automated setup with dependency handling
- **Modern CLI tools**: Enhanced alternatives for common commands
- **Custom prompt**: Context-aware with git integration
- **Window manager**: Wayland-based tiling configuration

## Structure

```
.
├── dot_config/
│   ├── shell/           # Shared shell config (env, aliases, functions)
│   ├── river/           # Window manager configuration
│   └── starship.toml    # Prompt configuration
├── dot_zshrc            # Zsh initialization
├── dot_bashrc           # Bash initialization
└── install.sh           # Bootstrap script
```

## Installation

### Quick Start

```bash
./install.sh
```

This will install chezmoi (if needed) and apply all configurations.

### Manual Installation

```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply wellcaffeinated/dotfiles
```

## Configuration

### Shell Environment

- **Editor**: Configured for Neovim
- **Path**: Includes `~/.local/bin`, `~/bin`, and language-specific paths
- **Locale**: UTF-8 by default

### Shell Features

- Vi mode support with visual indicators
- Smart history management (deduplication, persistence)
- Auto-suggestions and syntax highlighting
- Directory shortcuts and navigation helpers
- Safe defaults (interactive confirmations for destructive operations)

### Custom Functions

- `mkcd`: Create and enter directory
- `projroot`: Navigate to git repository root
- `reload`: Reload shell configuration

### Window Manager (River)

Tiling window manager with:
- Tag-based workspace system
- Keyboard-driven workflow
- Screenshot utilities
- Idle management and screen locking
- Notification support

## Customization

Configuration follows the [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) specification where possible.

### Adding Custom Config

Shared shell configuration can be extended in:
- `~/.config/shell/env` - Environment variables
- `~/.config/shell/aliases` - Command aliases
- `~/.config/shell/functions` - Shell functions

### Shell-Specific Config

Zsh plugins are declared in `.zsh_plugins.txt` and automatically loaded via the plugin manager.

## Maintenance

### Update Dotfiles

```bash
chezmoi update
```

### Edit Configuration

```bash
chezmoi edit ~/.zshrc
chezmoi apply
```

### Add New Files

```bash
chezmoi add ~/.config/newfile
```

## Dependencies

Core dependencies are installed automatically where possible. The setup detects available tools and adjusts aliases accordingly.

### Essential
- chezmoi (installed by bootstrap script)
- git

### Optional Enhancements
- Modern CLI alternatives (auto-detected)
- Shell plugins (auto-installed)
- Font with icon support (for prompt)
