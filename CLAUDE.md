# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a NixOS system configuration using Nix flakes and home-manager. It manages two hosts (`fractal` desktop, `thinkpad` laptop) with shared modules and roles.

## Common Commands

These helper scripts are installed via `modules/nixtools.nix`:

```bash
nxs   # nixos-rebuild switch --flake /etc/nixos  (apply configuration)
nxc   # nixos-rebuild build --flake /etc/nixos   (build without activating)
nxb   # nixos-rebuild boot --flake /etc/nixos    (build and add boot entry, no activation)
nxt   # nixos-rebuild test --flake /etc/nixos    (activate temporarily, no boot entry)
nxu   # nix flake update --flake /etc/nixos      (update flake.lock)
nxe   # open home.nix in editor
```

For manual flake operations:
```bash
nix flake check /etc/nixos    # validate flake
nix flake show /etc/nixos     # show outputs
```

## Architecture

### Entry Point
`flake.nix` is the root. It defines `nixosConfigurations` for each host and passes `specialArgs` (theme colors, fonts, users) to all modules. Home-manager is integrated as a NixOS module (not standalone).

### Layer Structure

```
flake.nix
  └── hosts/<hostname>/configuration.nix   # host-specific hardware + role import
        └── roles/role-*-config.nix        # role bundles (desktop, headless, etc.)
              └── modules/*.nix            # reusable feature modules
```

### Key Directories

- `hosts/` — One subdirectory per machine. Each has `configuration.nix` (system settings, primary screen, wallpaper) and `hardware-configuration.nix` (disk UUIDs, CPU microcode).
- `roles/` — Composable role files that bundle modules. `role-base-config.nix` defines shared NixOS options (`isNixOS`, `isDesktop`, `keyboardLayout`) and sets `home-manager.extraSpecialArgs` (so HM modules receive `keyboardLayout` and `isDesktop`).
- `modules/` — NixOS-level feature modules. Each module that has a `hm.nix` applies it to all users from `specialArgs.users` directly in its `default.nix`. Modules own both their system-level and home-manager configuration.
- `users/` — One file per user (`hy.nix`, `egor.nix`). Each declares `name`, `homedir`, and `stateVersion`. Imported into `specialArgs.users` in `flake.nix`.
- `assets/` — Wallpaper images referenced by host configs.
- `home.nix` — Loops over `users` from `specialArgs` to generate base `home-manager.users.*` entries (username, homeDirectory, stateVersion). Module-specific HM config is applied by each module's own `default.nix`.

### Multi-User Architecture

Users are declared in `users/*.nix` and imported into each nixosConfiguration's `specialArgs`:
```nix
users = [
  (import ./users/hy.nix)
  (import ./users/egor.nix)
];
```
Each user file is a simple attrset: `{ name = "hy"; homedir = "/home/hy"; stateVersion = "24.05"; }`.

- `home.nix` generates base `home-manager.users.<name>` entries (identity only) for each user.
- Role files generate `users.users.<name>` (NixOS system accounts) by looping over the `users` list.
- Each NixOS module applies its `hm.nix` to **all users** via `builtins.listToAttrs (map (...) users)`. The role controls which modules are active; active modules automatically configure every user.

### Dual Desktop Role Design

There are two parallel desktop roles that can be swapped in `hosts/<hostname>/configuration.nix`:

| Role | Module | Status |
|---|---|---|
| `role-x11-desktop-config.nix` | `modules/desktop-x11/` | Stable — i3 window manager on X11 |
| `role-wayland-desktop-config.nix` | `modules/desktop-wayland/` | WIP — Hyprland on Wayland |

The desktop module is selected by importing the desired role in the host configuration. Both roles expose the same `desktop` option namespace (`desktop.enable`, `desktop.primaryScreen`, `desktop.wallpaper`), so host configs don't change when switching roles.

`modules/desktop-x11/` contains i3 config, i3status config, and xrandr multi-monitor scripts.
`modules/desktop-wayland/` configures Hyprland, Waybar, pipewire audio, NVIDIA drivers for Wayland (PRIME sync, open kernel module), dunst notifications, GTK/cursor theming, and XDG MIME associations via home-manager.

### Theme System

Theme values (colors, fonts) are defined in `flake.nix` under `specialArgs` and passed to all modules. Modules receive `theme` as a module argument. The color scheme is One Dark; font is Inconsolata Nerd Font Mono.

### Custom Packages

`modules/st/` compiles the suckless `st` terminal from source with patches applied. Patches are `.diff` files in that directory; `my-patch.nix` generates the theme-colored config.h. (st is currently disabled in the wayland role; kitty is used instead.)

### Notable Config Details

- `fractal`: AMD/NVIDIA hybrid hardware (PRIME sync), primary display `DP-0`, ext4 on `/dev/disk/by-label/NIXROOT`; two users: `egor` and `hy`
- `thinkpad`: Intel hardware, PostgreSQL 14 at `/data/postgresql`, portable GRUB install
- Both use `nixos-unstable` nixpkgs
- Sudo without password is configured for the `wheel` group
- SSH on `fractal` has password auth disabled
