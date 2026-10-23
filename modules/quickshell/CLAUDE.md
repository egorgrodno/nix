# Quickshell

The bar and everything drawn with it: panels, notifications, OSD, launcher, lock screen, and the greeter in `greeter/`. `shell.qml` is the root. This file covers what no single file shows.

**Build.** Every `*.qml` here is linked into `~/.config/quickshell`. `default.nix` also generates `Theme.qml`, `Host.qml`, `Programs.qml` and `symbols.json`. The `quickshell` user unit has no useful PATH, so every program the bar runs **must** come from `Programs.qml`.

**Running programs.** A program the bar opens **must** start through `Launcher.run`, which gives it a scope of its own. A plain child dies when the bar restarts.

**State.** The bar's own state lives under `Quickshell.statePath`. State shared with scripts (the color scheme, the night light) sits in `$XDG_STATE_HOME`.

**IPC.** Hyprland's binds and scripts reach the bar through `quickshell ipc call <target> <function>`, each target an `IpcHandler`. Renaming a target or function breaks its callers: the binds in `modules/desktop/default.nix`, and `lockCommand` and the desktop entries in `default.nix`.

**Layers.** Hyprland's `layer_rule`s in `modules/desktop/default.nix` match the bar's surfaces by `WlrLayershell.namespace`. Renaming a namespace drops its rules.

**Panels.** A panel builds on `Panel.qml`. Its focus grab, layer and fixed-size surface each work around Hyprland, and its comments say how.

**Look.** Meters, sparks and sliders fill in blue, and colour marks state:

| Colour | State |
|---|---|
| Blue | Focus, or something on: a connected Bluetooth device, a VPN up |
| Faint grey | A muted or dimmed meter |
| Yellow, red | Warnings |
| Red | A muted speaker or microphone |
| Green | Charging |

**Greeter.** The greeter's config holds `greeter/` and the files `greeterConfig` copies, nothing else. A bar file the greeter comes to use, directly or through another file, **must** join that list. `ColorScheme.qml` is the exception: `greeter/` has its own, which a copy of the bar's would replace. The build does not catch a missing one, and a rebuild never restarts greetd, so the breakage shows only at the next boot.

**Debugging.** `Monitors.qml`, `Curtain.qml` and `Lock.qml` log to `journalctl --user -u quickshell`, and the greeter to `journalctl -u greetd`.
