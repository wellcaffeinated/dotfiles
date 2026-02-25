#!/usr/bin/env bash
# resurrect-save-guard.sh
#
# Prevents tmux-resurrect from losing sessions due to empty saves.
#
# Problem: When the system shuts down, tmux-continuum (or systemd) may
# trigger a save after all panes have already exited, producing an empty
# session file and updating the "last" symlink to point to it. On next
# boot, resurrect restores the empty file and the real session is lost.
#
# Fix: After every save (via @resurrect-hook-post-save-all) and at tmux
# startup (via run-shell before TPM init), this script checks whether
# "last" points to a valid save. If not, it reverts the symlink to the
# most recent save that contains actual pane data.

resurrect_dir="${HOME}/.tmux/resurrect"
last_link="${resurrect_dir}/last"

# Nothing to guard if there's no last symlink
[ -L "$last_link" ] || exit 0

current_file=$(readlink -f "$last_link" 2>/dev/null)
[ -f "$current_file" ] || exit 0

# A valid resurrect file must contain at least one "pane" line.
# Format: pane<TAB>session<TAB>window<TAB>...
if grep -q '^pane' "$current_file" 2>/dev/null; then
  exit 0 # Save looks good
fi

# Current save is empty/corrupt — find the most recent valid one
for f in $(ls -t "${resurrect_dir}"/tmux_resurrect_*.txt 2>/dev/null); do
  [ "$f" = "$current_file" ] && continue
  if grep -q '^pane' "$f" 2>/dev/null; then
    ln -sf "$(basename "$f")" "$last_link"
    # Best-effort notification (may fail during shutdown, that's fine)
    tmux display-message "resurrect-save-guard: reverted empty save to $(basename "$f")" 2>/dev/null
    exit 0
  fi
done
