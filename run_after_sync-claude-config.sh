#!/bin/bash
# Sync claude config to CLAUDE_CONFIG_DIR if set
# This copies files without overwriting existing ones

# Exit if CLAUDE_CONFIG_DIR is not set
[ -z "$CLAUDE_CONFIG_DIR" ] && exit 0

# Source directory (where chezmoi installs dot_claude/)
SOURCE_DIR="$HOME/.claude"

# Exit if source directory doesn't exist
[ -d "$SOURCE_DIR" ] || exit 0

# Create target directory if it doesn't exist
mkdir -p "$CLAUDE_CONFIG_DIR"

# Copy files without clobbering existing ones
# Using a loop to check each file individually for portability
for file in "$SOURCE_DIR"/*; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    target="$CLAUDE_CONFIG_DIR/$filename"

    if [ ! -e "$target" ]; then
        cp -r "$file" "$target"
        echo "Copied $filename to $CLAUDE_CONFIG_DIR"
    fi
done
