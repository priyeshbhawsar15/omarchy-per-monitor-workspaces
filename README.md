# Per-monitor Workspaces for Shibumi

Give every screen its own set of workspaces with a presentation that matches
Shibumi's workspace pill, markers, color tokens, hover feedback, and tooltips.
`SUPER+3` always means *this screen's third workspace* — never "jump to
whichever monitor happens to own workspace 3".

This is a Shibumi-only visual fork of
[`mmsbrggr/omarchy-per-monitor-workspaces`](https://github.com/mmsbrggr/omarchy-per-monitor-workspaces).
It preserves the upstream named-workspace model, hotplug handling, mouse
controls, and Lua actions. The original project is MIT-licensed; its copyright
and attribution are retained in [LICENSE](LICENSE).

![Two bars at the same moment: one screen sits on workspace 1, the laptop on workspace 4](docs/bar.png)

## Why

Omarchy binds `SUPER+1..0` to ten global workspaces shared by every monitor. On
a laptop alone that is fine. Plug in a second screen and it grates: you press
`SUPER+1` on your big screen and focus jumps to the laptop, because that is
where workspace 1 happens to live. The screen you were looking at does nothing.

With this plugin each monitor gets its own set, the way dwm, awesome and i3 do
it. Nothing is hardcoded — no monitor names, no workspace rules. A screen gets
its own set the first time you press a slot key on it.

## How it works, honestly

**Hyprland has no per-monitor workspaces.** Its workspaces are global: one flat
list, any of which can be shown on any monitor. There is no lower level to
configure — a native version of this would have to come from Hyprland itself.

So this plugin builds the idea on top of what Hyprland does offer: *named*
workspaces. Each screen gets workspaces named after it — `<screen>:1`,
`<screen>:2` — and `SUPER+1` resolves to a name at the moment you press it,
from whichever screen has focus. You never see those names; the bar labels
everything by position.

That is the whole trick, and it explains the edges: a workspace still belongs to
Hyprland's one global list, so unplugging a screen leaves its workspaces parked
on a surviving one, and a returning screen has to be put back on its own. Both
are handled — see [Unplugging a screen](#unplugging-a-screen).

## Requirements

- Omarchy 4 (Quattro) with Shibumi Shell installed and active
- Hyprland with the Lua configuration

## Install

```sh
omarchy plugin add https://github.com/priyeshbhawsar15/omarchy-per-monitor-workspaces.git --enable
```

This repository is intended for Shibumi Shell, not the stock Omarchy bar. Its
widget needs the Shibumi State presentation library and must replace
`hancore.shibumi.workspaces` in the active Shibumi layout. Use the managed,
pinned installer in the accompanying personal setup repository rather than this
mutable-HEAD example.

### Keyboard shortcuts

Shortcuts are required for `SUPER+N` to select the focused monitor's workspace.
This fork deliberately does not offer a popup that edits `bindings.lua`; a
reproducible installer should add and remove the binding with the feature.

By hand, load the supplied shortcut module from `~/.config/hypr/bindings.lua`:

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/mmsbrggr.per-monitor-workspaces/hypr/init.lua")
```

> Omarchy's plugin installer never runs code from a plugin — it only clones
> files — so a plugin cannot add keybindings to your config on its own.

## Keys

### On one screen

| Key | Does |
| --- | --- |
| `SUPER + 1..5` | Focus this screen's workspace 1..5 |
| `SUPER + SHIFT + 1..5` | Move the window there and follow it |
| `SUPER + SHIFT + ALT + 1..5` | Move the window there, stay where you are |
| `SUPER + TAB` / `SUPER + SHIFT + TAB` | Next / previous workspace on this screen |
| `SUPER + scroll` | Same, with the wheel |
| `SUPER + CTRL + TAB` | Back to this screen's previous workspace |
| `SUPER + L` | Toggle this workspace between dwindle and scrolling |

Cycling walks the slots in order whether or not you have used one yet — Hyprland
deletes a workspace as soon as its last window closes, so a cycle over only the
live ones would usually be a cycle of one.

### Across screens

| Key | Does |
| --- | --- |
| `SUPER + CTRL + ALT + ←↑↓→` | Focus the screen in that direction |
| `SUPER + CTRL + SHIFT + ←↑↓→` | Send the window there and follow |
| `SUPER + SHIFT + ALT + ←↑↓→` | Send everything on this workspace there |
| `SUPER + CTRL + ALT + SHIFT + ←↑↓→` | Swap this screen's windows with that screen's |

Directions are physical, so there are no monitor numbers to memorise. These move
**windows, not workspaces** — every workspace stays on the screen it belongs to,
and focus follows what you sent. Swapping keeps both screens' tiling intact.

### With the mouse

On the dots: **left-click** to focus, **right-click** to send the focused window
there, **scroll** to cycle. Each bar acts on its own screen.

### What this changes in Omarchy's defaults

`SUPER + 6..0` are removed — with per-monitor slots they could only pull you to
another screen. `SUPER + CTRL + TAB` and `SUPER + SHIFT + ALT + ←↑↓→` are
rebound for the same reason.

`SUPER + L` is rebound because Omarchy's version breaks here. Its toggle names
the workspace by *id*, and a named workspace's id is a negative number no
workspace rule ever matches — so the key does nothing, and still tells you it
worked. Ours names the workspace the way the rest of this plugin does, and
remembers your choice in `~/.local/state/omarchy/`, since a rule set at runtime
is gone the next time Hyprland reads its config.

Everything else is untouched.

## Configuration

Five slots per screen by default:

```sh
omarchy bar set mmsbrggr.per-monitor-workspaces count 8 --json
```

That is an ordinary widget setting on your `shell.json` entry, which is where
Omarchy keeps plugin settings — you can edit it there directly too. The widget
projects it into `~/.local/state/omarchy/` for the shortcuts to read, and hands
the running Hyprland the same number, so the keys change along with the dots
rather than at the next reload.

### Shibumi appearance settings

Use Shibumi Control Center → **Bars** → **Workspaces** to change this widget's
appearance. The widget reads the active Shibumi profile's G2 appearance
settings, so its fill color, content tone, and opacity stay in sync with the
familiar Workspaces editor.

It also syncs Shibumi's **Marker Style** (Default, Numbers, Magic, Kanji, Frame,
Aurora, Pacman) and **Visible Workspaces** mode (Ten, Five, Active only), rendering
all 7 Shibumi workspace styles for per-monitor workspaces.

This bridge deliberately shares visual settings only. The **workspaces per
monitor** count remains the plugin's own setting above because it also controls
Hyprland shortcuts. Shibumi's native workspace service must remain enabled: it
provides the supported G2 settings contract and safe fallback during Shibumi
updates, while this widget remains the displayed workspace provider.

### Your own keybindings

The shortcuts are one opinionated arrangement; the actions underneath are the
part that matters. Load `hypr/actions.lua` instead of `hypr/init.lua` and bind
whatever you like:

```lua
local pmw = dofile(os.getenv("HOME") ..
  "/.config/omarchy/plugins/mmsbrggr.per-monitor-workspaces/hypr/actions.lua")

o.bind("SUPER + code:10", "Workspace 1",  pmw.focus_slot(1))
o.bind("SUPER + TAB",     "Next",         pmw.cycle(1))
o.bind("SUPER + ALT + L", "Screen right", pmw.focus_monitor("r"))
```

`focus_slot`, `move_to_slot`, `move_to_slot_silently`, `cycle`, `focus_monitor`,
`send_window`, `send_workspace`, `swap_workspaces`, `toggle_layout`, plus
`count`. Each takes its argument and returns a function to bind.

Taking this path means Omarchy's `SUPER + L` stays as it is, which on a named
workspace does nothing — bind `toggle_layout` if you want that key back:

```lua
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Toggle workspace layout", pmw.toggle_layout())
```

`count` changes while Hyprland runs, whenever you change the setting. Keys that
depend on how many slots there are go inside `on_count`, which runs immediately
and again on every change. A shrink arrives the same way as a growth, so drop
the keys before binding the current set — unbinding a key that is not bound
costs nothing:

```lua
pmw.on_count(function(count)
  for slot = 1, 10 do hl.unbind("SUPER + code:" .. (slot + 9)) end

  for slot = 1, math.min(count, 10) do
    o.bind("SUPER + code:" .. (slot + 9), "Workspace " .. slot, pmw.focus_slot(slot))
  end
end)
```

## Unplugging a screen

Hyprland parks a disconnected screen's workspaces on a surviving one. The bar
shows them after your numbered slots, as a display glyph rather than a number —
the number they carry belongs to the screen they came from, and printing it
would put a second "4" after this screen's "5". Hover to see where it came from,
and `SUPER + TAB` reaches them, so nothing is stranded.

![The bar showing workspaces 1 to 5 followed by an orange display icon](docs/parked.png)

Plug the screen back in and its workspaces come home with their windows. Left to
itself Hyprland hands a returning screen a fresh global workspace, and a dock can
put the same panel on a different connector than last time, which leaves two
screens showing each other's workspaces. The widget sorts both out.

Screens are identified by description rather than connector, because `DP-2` and
`DP-3` can swap on replug. Two identical panels that report no serial describe
themselves alike; those get the connector appended to tell them apart.

## Uninstall

```sh
omarchy plugin remove mmsbrggr.per-monitor-workspaces
```

Restore `hancore.shibumi.workspaces` to the Shibumi layout before removal, then
remove the `pcall(dofile, ...)` line from `~/.config/hypr/bindings.lua`. The
managed installer performs both actions and restores its backup.

## License

MIT. The original bar widget is derived from Omarchy's built-in workspace widget.
