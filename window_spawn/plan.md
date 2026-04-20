# Window Spawn - KDE Window Rule Generator

## Problem
Setting up KDE window rules to pin applications to specific monitors requires navigating through multiple GUI menus. This is tedious when working with many DCC apps (Houdini, Nuke, DaVinci, etc.).

## Goal
A simple bash tool that lets you:
1. Click any window
2. Pick a monitor
3. Automatically creates a KDE window rule to always open that app on that monitor

## Dependencies
**Zero extra dependencies** - uses only tools included in a stock Rocky 9 KDE install:
- `xprop` - get window class from a clicked window (X11 built-in)
- `xrandr` - list connected monitors (X11 built-in)
- `kdialog` - GUI prompts (KDE built-in)
- `qdbus` - reload kwin rules (KDE built-in)
- `bash` - script glue
- `uuidgen` - generate rule IDs (util-linux, built-in)

## How It Works

### Flow

```
User runs window_spawn.sh
        |
        v
kdialog shows instructions: "Click a window..."
        |
        v
xprop WM_CLASS captures the window class
        |
        v
xrandr --listmonitors gets available monitors
        |
        v
kdialog --menu shows monitor list to pick from
        |
        v
Script writes rule to ~/.config/kwinrulesrc
        |
        v
qdbus org.kde.KWin /KWin reconfigure reloads rules
        |
        v
kdialog confirms success
```

### kwinrulesrc Format

Each rule is an INI group with a UUID key:

```ini
[General]
count=2
rules=existing-uuid,new-uuid

[new-uuid]
Description=WindowSpawn: firefox on DP-1
clientmachine=localhost
wmclass=firefox
wmclassmatch=1
screenrule=3
screen=1
```

Key fields:
- `wmclass` - the window class to match
- `wmclassmatch` - 1 = exact match
- `screen` - monitor index (0, 1, 2...)
- `screenrule` - 3 = "Force" (always apply), 2 = "Apply Initially" (only on first open)
- `Description` - prefixed with "WindowSpawn:" so our rules are identifiable

### Architecture

Single file: **`window_spawn.sh`**

No need for multiple files. The script is linear:

```
window_spawn.sh
  |-- capture_class()    # xprop WM_CLASS, parse output
  |-- list_monitors()    # xrandr --listmonitors, parse into names + indices
  |-- pick_monitor()     # kdialog --menu with monitor list
  |-- write_rule()       # append rule to kwinrulesrc, update [General]
  |-- reload_kwin()      # qdbus reconfigure
```

### Additional Features (optional, phase 2)

- **`window_spawn.sh --list`** - show all WindowSpawn rules currently set
- **`window_spawn.sh --remove`** - kdialog menu to pick and delete a rule
- **`window_spawn.sh --force`** vs **`--initial`** - choose between "always force to monitor" or "only on first open"
- Option to also set workspace number, not just monitor
- Option to set fullscreen/maximized state

### Edge Cases to Handle

- Window with no WM_CLASS (rare, show error via kdialog)
- Rule already exists for that wmclass (offer to update instead of duplicate)
- kwinrulesrc doesn't exist yet (create it with empty [General])
- Parsing xprop output: format is `WM_CLASS(STRING) = "instance", "class"` - use the class (second string)
- Monitor index mapping: xrandr indices vs kwin screen numbers (verify they match)

### Testing

1. Run script, click a terminal window, assign to monitor 2
2. Open a new terminal - should appear on monitor 2
3. Run `--list` to verify rule shows up
4. Run `--remove` to delete it
5. Open terminal again - should go back to default behavior
