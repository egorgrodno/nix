---
name: dev-mode
description: >
  Iterate on a program's configuration live, without a nixos-rebuild. Swaps
  home-manager's read-only store symlinks in ~/.config for writable copies, reloads
  the program on change, then ports the edits back into the Nix source and relocks.
  Trigger on "dev mode", "live edit", "tweak the bar", "iterate on the quickshell
  QML", "iterate on the hyprland config", "try some colors", or any request to see a
  config change quickly instead of rebuilding. Covers quickshell, hyprland,
  kitty, nvim, zsh, gtk and anything else home-manager writes into ~/.config.
---

# Dev mode for home-manager configs

Run `/etc/nixos/.claude/skills/dev-mode/devmode.sh` by its absolute path, from `/etc/nixos`, as `verify` resolves the flake as `.#`. Dev mode covers home-manager's files only: not `/etc`, and not runtime state such as the wallpaper. The greeter runs from the store under greetd, beyond its reach, so a change to `greeter/` or to a bar file the greeter shares shows there only at the next boot.

## The loop

```bash
devmode.sh on quickshell      # store symlinks -> writable copies
devmode.sh reload quickshell  # once: Quickshell then reloads on every save
# edit ~/.config/quickshell/Bar.qml
devmode.sh diff quickshell    # what changed, as a unified diff
# port the diff into the Nix source, below
devmode.sh verify quickshell  # proves the source regenerates the edited file
devmode.sh off quickshell     # restore the symlinks
nxt                           # activate the ported source
```

| Command | Effect |
|---|---|
| `on <program>...` | Unlock, and print how the program reloads. |
| `off <program>...`, `off --all` | Relock. Each edited file is saved first, with a `.patch`, under `~/.local/state/nix-devmode/edits/<program>/`. |
| `status` | What is unlocked, edited or new. |
| `diff [program]` | Store original against live file: the input to porting. |
| `verify [program]` | Build each unlocked file from the Nix source, in about a second, and compare it to the live copy. |
| `reload <program>` | Make the program re-read its config. |
| `watch <program>` | Reload on every change. It runs until interrupted, so start it in the background. |
| `list` | Known programs and the paths each owns. |
| `preflight` | Exits non-zero while anything is unlocked. Run it before any rebuild: one with an edited file unlocked aborts with `Existing file '…' would be clobbered`, which `off --all` clears. |

## Testing live

- **Quickshell.** A text-rendering change needs another `reload`.
- **Errors.** A QML error leaves the running bar in place and goes to `journalctl --user -u quickshell`. `hyprctl reload` prints a Lua error and keeps the running config.
- **hypridle.** `reload hypridle` restarts it, which drops every app's idle inhibit.
- **Lock screen.** Raising it, with `quickshell ipc call lock lock`, locks the real session. Only the user's password unlocks it.

## Porting the edits back

Nothing survives a rebuild until it reaches the Nix source. The live file is a flattened rendering of that source, with interpolations expanded and conditionals resolved to one branch. No script inverts that, so porting is judgment, and `verify` checks it.

| Live file | Nix source |
|---|---|
| `.config/quickshell/*.qml` | `modules/quickshell/`, same name; `Theme.qml`, `Programs.qml` and `Host.qml` from its `default.nix` |
| `.config/hypr/hyprland.lua` | `modules/desktop/default.nix`, `wayland.windowManager.hyprland`: `settings` for the `hl.config`, monitor and rule calls, `extraConfig` for the Lua after them |
| `.config/hypr/hypridle.conf` | `modules/desktop/default.nix`, `services.hypridle` |
| `.config/kitty/kitty.conf` | `modules/desktop/default.nix`, `programs.kitty` |
| `.config/kitty/*-theme.auto.conf` | `modules/desktop/default.nix`, `xdg.configFile`, from `kittyColors` |
| `.config/gtk-3.0/settings.ini`, `gtk-4.0` | `modules/desktop/default.nix`, `gtk` |
| `.config/nvim/init.lua` | `modules/neovim/hm.nix` |
| `.config/nvim/lua/config.lua` | `modules/neovim/lua-config.nix` |
| `.config/nvim/snippets/all.lua` | `modules/neovim/snippets.lua` |
| `.config/zsh/.zshrc` | `modules/zsh/hm.nix`, `modules/zsh/init-config.nix` |
| `.config/git/config` | `modules/git/hm.nix` |

### Procedure

1. `devmode.sh diff <program>`: the hunks to account for.
2. Open the generating source **and read the region around the match**. One flat line may come from an interpolation, a conditional or a generated list.
3. Edit the source so it would produce the edited output. Never paste a rendered value that came from an expression.
4. Run `devmode.sh verify <program>` until it prints `ok` for every file. Any diff it prints is not yet ported.
5. Where the source branches, check the branches this host does not render (below).
6. Copy each file created while unlocked into the source, and `git add` it: the flake sees only tracked files, and `verify` does not check new ones. `off` moves such a file into the edits directory unless the current generation already holds it.
7. `devmode.sh off <program>`, then `nxt`.

### What flattening destroys

- **Interpolated store paths.** `pcmanfm: "${lib.getExe pkgs.pcmanfm}"` in `Programs.qml` renders as `/nix/store/6rkhi5…-pcmanfm-1.3.2/bin/pcmanfm`. Pasted back, it pins a path the next garbage collection deletes. Restore the `${pkgs.…}` form.
- **Theme colors.** A hex value in a diff is almost always a rendered `theme.*` reference: `#16191D` is `theme.dark.background.main`, `#61AFEF` is `theme.dark.blue`. A literal ignores the color scheme. In QML a color is a `Theme.*` property and an overlay is `Theme.tint(a)`.
- **Attrsets rendered as text.** Kitty's config and Hyprland's settings, monitors and rules come from attrsets: `modify_font cell_height 133%` is `programs.kitty.settings.modify_font = "cell_height 133%"`. Hyprland's binds, submap and startup are Lua in `extraConfig`, and port back as Lua.
- **Resolved conditionals.** The live file holds one branch. The others never appear in the diff.

### Branches this host does not render

A branch on the keyboard layout, `isDesktop` or the host renders only one way here. The layout branches sit in `modules/neovim/lua-config.nix`, `modules/desktop/default.nix` and `modules/zsh/init-config.nix`: hallmack on `fractal`, qwerty on `thinkpad`. An edit inside one belongs in the right branch, and often in both.

Either host's file builds from either machine, without a rebuild:

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.fractal.config.home-manager.users.egor.xdg.configFile."hypr/hyprland.lua".source'
```

Build the other host's file before editing the source and again after, then diff the two. The diff shows exactly the intended change, or nothing when the change belongs to this host's branch alone. The standalone Neovim profiles, `.#homeConfigurations.neovim-qwerty` and `neovim-hallmack`, build the same way with `--impure`, as `mkNeovimHome` reads `$USER`.
