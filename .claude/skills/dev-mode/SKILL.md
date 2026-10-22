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

Home-manager links every config in `~/.config` to a read-only `/nix/store` path, so a one-character style tweak costs a full rebuild. Dev mode replaces those links with writable copies, so edits land instantly and the running program reloads on a signal. The edits are then ported back into the Nix source and the links restored.

`devmode.sh` lives beside this file. Invoke it by absolute path: `/etc/nixos/.claude/skills/dev-mode/devmode.sh`.

## The loop

```bash
devmode.sh on quickshell      # store symlinks -> writable copies
devmode.sh reload quickshell  # once: Quickshell then reloads on every save
$EDITOR ~/.config/quickshell/Bar.qml
devmode.sh diff quickshell    # what changed, as a unified diff
# ... Claude ports the diff into the Nix source — see "Porting the edits back" ...
devmode.sh verify quickshell  # proves the source now regenerates the edited file
devmode.sh off quickshell     # restore the symlinks
nxs                           # make it real
```

**The script does the mechanics; Claude does the porting.** `on`/`reload`/`watch`/`off` are pure plumbing — symlink swapping and signals. Turning an edited config file back into Nix is a judgment task, because the live file is a *flattened rendering* of the source: interpolations are already expanded and conditionals already resolved to one branch. No script can invert that. `verify` is what makes the judgment checkable.

`off` saves any edited file to `~/.local/state/nix-devmode/edits/<program>/` with a `.patch` beside it before relocking, so the bytes are never lost by relocking early. That is the only thing the script guarantees to preserve — an edit that is never ported still vanishes from the live tree on the next rebuild. A file created while unlocked, such as a new QML file, is linked into the current generation if that holds it, which an activation in the meantime does; any other is moved into the same directory, since a plain file blocks the activation that adds it. Plain files already there at `on` are left alone.

| Command | Effect |
|---|---|
| `on <program>...` | Unlock. Records each store origin in `~/.local/state/nix-devmode/<program>.tsv`. On a laptop, also holds off idle, sleep and the lid switch. |
| `off <program>...` / `off --all` | Save edits, restore the symlinks, settle files created while unlocked, drop the state. Releases the inhibitor once nothing is unlocked. |
| `status` | Which programs are unlocked, which files are edited or new, and whether the inhibitor is held. |
| `diff [program]` | Unified diff, store original against live file. The input to porting back. |
| `verify [program]` | Regenerate each file from the Nix source and compare to the live copy. Exit 0 only when the source reproduces the edits byte for byte. |
| `reload <program>` | Signal the program to re-read its config. |
| `watch <program>` | Poll every 0.5s and reload on change. Foreground; Ctrl-C to stop. |
| `list` | Known targets and the paths each owns. |
| `preflight` | Exits non-zero if anything is unlocked. Run before a rebuild. |

Any name not in `list` falls back to `~/.config/<name>`.

`verify` costs about a second — it evaluates one file's derivation, not the system — so run it after every porting attempt rather than reaching for a rebuild.

## Reload behaviour

| Program | How it picks up a change |
|---|---|
| `hyprland` | `hyprctl reload` |
| `kitty` | `pkill -USR1 kitty`. All windows, live. |
| `hypridle` | `systemctl --user restart hypridle` |
| `quickshell` | `systemctl --user restart quickshell`. It reloads on save by itself, but only once restarted after `on`, and a text-rendering change needs a restart regardless. |
| `nvim`, `zsh` | No signal — new instances pick it up (`exec zsh` for the current shell). |

A QML error on save leaves the running bar in place and posts a critical "Quickshell failed to reload" notice with the error. A Lua syntax error in `hyprland.lua` is rejected by `hyprctl reload` with the error printed, leaving the running config intact.

The lock screen is part of the bar, raised by `quickshell ipc call lock lock`, and unlocks only with the real password. The greeter is not: greetd runs its QML, `modules/quickshell/greeter/`, from the store, so dev mode cannot reach it and a change shows at the next login after a rebuild.

## Porting the edits back

This is the part that matters — dev mode is scratch space, and nothing survives a rebuild until it reaches the Nix source. Run `devmode.sh diff`, then apply each hunk to the source that generates that file:

| Live file | Nix source |
|---|---|
| `.config/quickshell/*.qml` | `modules/quickshell/`, the same name; `Theme.qml`, `Programs.qml` and `Host.qml` from its `default.nix` |
| `.config/hypr/hyprland.lua` | `modules/desktop/default.nix` — `wayland.windowManager.hyprland` (~887): `settings` for the `hl.config`, monitor and rule calls, `extraConfig` for the Lua after them |
| `.config/hypr/hypridle.conf` | `modules/desktop/default.nix` — `services.hypridle` (~969) |
| `.config/kitty/*` | `modules/desktop/default.nix` — `programs.kitty` (~411) |
| `.config/gtk-3.0/settings.ini`, `gtk-4.0` | `modules/desktop/default.nix` — `gtk` (~1011) |
| `.config/nvim/init.lua` | `modules/neovim/hm.nix` |
| `.config/nvim/lua/config.lua` | `modules/neovim/lua-config.nix` |
| `.config/nvim/snippets/all.lua` | `modules/neovim/snippets.lua` |
| `.config/zsh/.zshrc` | `modules/zsh/hm.nix`, `modules/zsh/init-config.nix` |
| `.config/git/config` | `modules/git/hm.nix` |

Line numbers drift; grep for the option name.

### Procedure

1. `devmode.sh diff <program>` — the hunks to account for.
2. Open the generating source **and read the surrounding region**, not just the matching line. What renders as one flat line may come from an interpolation, a conditional, or a generated list.
3. Edit the source so it would produce the edited output. Never paste a rendered value that came from an expression.
4. `devmode.sh verify <program>` — must print `ok` for every file. A diff here is the part not yet ported.
5. For a file with conditional branches, check the branches that do not render on this host (below).
6. `devmode.sh off <program>`, then `nxs`.

Never skip step 4. A port that looks right and a port that regenerates the file byte for byte are different claims, and only the second one survives a rebuild.

### What flattening destroys

- **Interpolated store paths.** `pcmanfm: "${lib.getExe pkgs.pcmanfm}"` in `Programs.qml` renders as `pcmanfm: "/nix/store/6rkhi5…-pcmanfm-1.3.2/bin/pcmanfm"`. Porting that back verbatim pins a store path that dies at the next garbage collection. Restore the `${pkgs.…}` form.
- **Theme colors.** A hex value in a diff is almost always a `theme.*` reference rendered out — `#16191D` is `theme.dark.background.main`, `#61AFEF` is `theme.dark.blue`. A literal undoes the theme routing and ignores the color scheme. In QML a color is a `Theme.*` property and an overlay is `Theme.tint(a)`, both of which follow it. If the color is genuinely new, add it to both palettes in `flake.nix`.
- **Attrsets rendered as text.** Kitty's config and Hyprland's settings, monitors and rules come from Nix attrsets; Hyprland's binds, submap and startup are Lua in `extraConfig` and port back as Lua. `font_size 12.0` is `programs.kitty.settings.font_size = 12.0`, not a string to paste into a text block.
- **Resolved conditionals.** The live file contains one branch. The others are invisible in the diff and are the easiest thing to break — see below.

### Conditional branches

`modules/neovim/lua-config.nix` carries nine `${if config.base.keyboard.layout == "hallmack" then … else …}` blocks, and the two renderings differ by roughly 780 lines. A host renders only its own layout's branch, **hallmack** on `fractal` and **qwerty** on `thinkpad`, so the other never appears in a local diff — yet both ship, as `homeConfigurations.neovim-qwerty` and `homeConfigurations.neovim-hallmack`.

An edit to a keymap inside one of those blocks must be made in the correct branch, and often in both. Render each one directly, without a rebuild:

```bash
nix build --impure --no-link --print-out-paths \
  '.#homeConfigurations.neovim-qwerty.config.xdg.configFile."nvim/lua/config.lua".source'
nix build --impure --no-link --print-out-paths \
  '.#homeConfigurations.neovim-hallmack.config.xdg.configFile."nvim/lua/config.lua".source'
```

Capture both store paths *before* editing the source, re-render after, and diff old against new for each branch. The branch that was edited should show exactly the intended change; the other should show nothing, unless the change was meant to apply to both. `--impure` is required — `mkNeovimHome` reads `$USER`.

The same applies to any option gated on `isDesktop`, `keyboardLayout`, or the host — the host that renders the branch is the only one where a mistake is visible.

## Rebuilding while unlocked

Home-manager's activation refuses to clobber a file it does not own. With a config unlocked and edited, `nxs` aborts at `checkLinkTargets`:

```text
Existing file '/home/egor/.config/quickshell/Bar.qml' would be clobbered
```

Nothing is lost — activation stops before touching anything. Run `devmode.sh off --all` and rebuild again.

The subtler case: if an unlocked file happens to be byte-identical to the store version, activation skips it with a warning and relinks everything else to the new generation, leaving that one file behind. `off` detects this and relinks into the *current* generation rather than the captured one. Always run `devmode.sh preflight` before a rebuild.

## Notes

- **Inhibitor.** A laptop is a host whose `hostnamectl chassis` reads `laptop`, which `base.isLaptop` pins. There `on` starts a `systemd-inhibit` against idle, sleep and the lid switch, so the screen stays up for screenshots and a suspend cannot strand a session; its PID is in `~/.local/state/nix-devmode/inhibit.pid`. Other hosts get none.
- `on` only touches symlinks whose immediate target matches `/nix/store/*-home-manager-files/*`. Restoring anything else — a fully resolved store path, for instance — makes the next activation treat the file as foreign and abort.
- Runtime state is out of scope. The wallpaper is set by Quickshell's picker through awww, not by a config file.
- System-level files under `/etc` are not home-manager's and are not covered.
