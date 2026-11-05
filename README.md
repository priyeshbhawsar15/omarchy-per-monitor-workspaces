# Per-monitor Workspaces pill for Shibumi

A Shibumi-styled workspace pill for Omarchy's built-in per-monitor workspaces.

Omarchy 4.5 gives every monitor its own workspaces 1-10, numbered in a block of
ten in Hyprland's global numbering: 1-10, 11-20, and so on. Omarchy owns those
workspaces, their keys and their hotplug handling. This widget only displays
them, so each bar shows its own monitor's block, numbered from 1.

- Left-click a dot to go to that workspace on the bar's monitor.
- Right-click a dot to move the focused window there.
- Scroll to cycle through the monitor's workspaces.
- Workspaces from an unplugged monitor appear after the dots with a monitor icon.

The `count` setting chooses how many dots to show. A workspace past the count
still appears while it exists. Appearance, Marker Style and Visible Workspaces
follow Shibumi's existing Workspaces settings.

It requires the Shibumi bar and Omarchy 4.5 or later, and adds no keybindings.

## Credits

Originally [omarchy-per-monitor-workspaces](https://github.com/mmsbrggr/omarchy-per-monitor-workspaces)
by Marcel Moosbrugger, which implemented per-monitor workspaces with named
workspaces and its own keymap. This fork keeps the widget and leaves the workspace
model to Omarchy. MIT licensed; see `LICENSE`.
