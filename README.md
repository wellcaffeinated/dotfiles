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

## Tmux Configuration

The tmux configuration includes:

- **Prefix key**: `Ctrl-a` (more ergonomic than default `Ctrl-b`)
- **Mouse support**: Enabled for easy pane resizing and scrolling
- **Vim keybindings**: `hjkl` for pane navigation, `vi` mode in copy mode
- **Better splits**: `|` for vertical split, `-` for horizontal split
- **256 colors** and **true color** support
- **Persistent sessions**: Auto-save/restore with plugins (optional)

### Quick Reference

| Key | Action |
|-----|--------|
| `Ctrl-a \|` | Split pane vertically |
| `Ctrl-a -` | Split pane horizontally |
| `Ctrl-a h/j/k/l` | Navigate panes (vim-style) |
| `Ctrl-a H/J/K/L` | Resize panes |
| `Ctrl-a c` | Create new window |
| `Ctrl-a r` | Reload config |

### Shell Aliases (when tmux is installed)

- `ta <name>` - Attach to session
- `ts <name>` - Create new session
- `tl` - List sessions
- `tkss <name>` - Kill session

### Optional: TPM (Plugin Manager)

For enhanced functionality (session persistence, better copy/paste), install [TPM](https://github.com/tmux-plugins/tpm):

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Then in tmux: `Ctrl-a` + `I` (capital i) to install plugins.

**Note**: Tmux config is fully functional without TPM.
