# Portable Bash Script Reference

## Getting the Script's Directory

To make a bash script work on any machine regardless of where it's installed, use this pattern to get the script's own directory:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### Breakdown

| Component | Purpose |
|-----------|---------|
| `${BASH_SOURCE[0]}` | Path to the current script (more reliable than `$0`) |
| `dirname` | Extracts the directory portion of the path |
| `cd ... && pwd` | Resolves to absolute path (handles symlinks and relative paths) |

### Usage Example

```bash
#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Reference other files relative to the script
CONFIG_FILE="$SCRIPT_DIR/config.env"
DATA_DIR="$SCRIPT_DIR/../data"

source "$CONFIG_FILE"
```

## Modifying .bashrc Safely

When adding lines to `.bashrc`, follow these practices:

### 1. Use a Marker Comment

```bash
MARKER="# My custom config"

if grep -qF "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
    echo "Already configured"
    exit 0
fi

echo "" >> "$HOME/.bashrc"
echo "$MARKER" >> "$HOME/.bashrc"
echo "source \"$SCRIPT_DIR/my_config.sh\"" >> "$HOME/.bashrc"
```

### 2. Verify Source Files Exist

```bash
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi
```

### 3. Provide User Feedback

```bash
echo "Configuration added to .bashrc"
echo "Run 'source ~/.bashrc' or open a new terminal to apply changes"
```

## Files in This Directory

- `aliases.sh` - Custom shell aliases
- `install_aliases.sh` - Adds aliases.sh reference to .bashrc
