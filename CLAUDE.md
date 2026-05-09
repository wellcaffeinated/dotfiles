# Project Description

Personal dotfiles repository managed with chezmoi.

## Instructions for Claude

**Important**: Do not update the README.md file unless explicitly asked to do so.

### File responsibilities

When adding new shell config, place code in the file matching its responsibility — don't merge unrelated concerns into one file:

- `dot_config/shell/env` — environment variables and `PATH` (sourced by bash and zsh)
- `dot_config/shell/aliases` — aliases (sourced by both)
- `dot_config/shell/functions` — shell functions (sourced by both — keep portable, no zsh- or bash-only syntax)
- `dot_zshrc` / `dot_bashrc` — shell-specific wiring (hooks, keybindings, completion setup)

When a feature has multiple parts, split them: e.g. a terminal-title helper goes in `functions` (just an escape sequence, portable), but the `add-zsh-hook precmd ...` registration belongs in `dot_zshrc`.

### Cross-platform & OS-specific config

The repo targets both macOS and Linux. To keep a single source of truth:

- Prefer **runtime guards** in plain shell over chezmoi templates: `command -v tool >/dev/null && ...`, `[ -s "$file" ] && source "$file"`, `[ "$(uname)" = "Darwin" ] && ...`. PATH entries pointing to nonexistent dirs are harmless, so unconditional `export PATH=...` is usually fine.
- Reach for chezmoi `.tmpl` files (with `{{ if eq .chezmoi.os "darwin" }}`) only when the OS-specific block is substantial or contains content that would error if present on the wrong OS.
- Never commit secrets/tokens. Machine-local secrets should live outside this repo (e.g. a gitignored `~/.config/shell/secrets` sourced from `env`).

## Navi Cheatsheet Tool

Navi is configured with dual cheat locations:
- `~/.local/share/navi/cheats/` - Default location for downloaded repos (via `navi repo add`)
- `~/.cheats/` - Personal cheats

Config file: `dot_config/navi/config.yaml`

Shell widget enabled in zshrc - press **Ctrl+G** to trigger navi inline.

Additional styling options are available in the config file (commented out).
