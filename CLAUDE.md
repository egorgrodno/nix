# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a NixOS system configuration using Nix flakes and home-manager. It manages two hosts (`fractal` desktop, `thinkpad` laptop) with shared modules and roles.

## Common Commands

These helper scripts are installed via `modules/nixtools/`:

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
`flake.nix` is the root. It defines `nixosConfigurations` for each host and passes `specialArgs` (the `theme`, the `users` list, and the `forAllUsers` helper) to all modules. Home-manager is integrated as a NixOS module, not standalone. The flake also exposes `homeConfigurations` (`neovim-qwerty`, `neovim-hallmack`) — standalone home-manager profiles for non-NixOS machines.

### Layer Structure

```
flake.nix
  └── hosts/<hostname>/configuration.nix   # host-specific hardware + role import
        └── roles/role-*-config.nix        # role bundles (desktop, headless, etc.)
              └── modules/*.nix            # reusable feature modules (all users)

users/<name>.nix                           # per-user identity + optional homeModules
  └── profiles/*.nix                       # per-user home-manager profiles (one user)
```

### Key Directories

- `hosts/` — One subdirectory per machine. Each has `configuration.nix` (system settings, primary screen) and `hardware-configuration.nix` (disk UUIDs, CPU microcode).
- `roles/` — Composable role files that bundle modules. `role-base-config.nix` defines shared NixOS options (`base.isNixosSystem`, `base.isDesktop`, `base.isHeadless`, `base.keyboard.layout`) and sets `home-manager.extraSpecialArgs` (so HM modules receive `keyboardLayout` and `isDesktop`). See `roles/README.md` for the full role catalog.
- `modules/` — NixOS-level feature modules. Each module that has a `hm.nix` applies it to all users through the `forAllUsers` helper (from `specialArgs`) in its `default.nix`. Modules own both their system-level and home-manager configuration.
- `profiles/` — Per-user home-manager profiles (for example `work.nix`). A profile is a home-manager module attached to a single user through that user's `homeModules`, never via a host or `forAllUsers`. See `profiles/README.md`.
- `users/` — One file per user (`egor.nix`, `forge.nix`). Each declares `name`, `homedir`, and `stateVersion`, and optionally `homeModules` (a list of profiles to attach to that user). Imported into `specialArgs.users` in `flake.nix`.
- `home.nix` — Loops over `users` from `specialArgs` to generate base `home-manager.users.*` entries (username, homeDirectory, stateVersion). Module-specific HM config is applied by each module's own `default.nix`.

### Multi-User Architecture

Users are declared in `users/*.nix` and imported into each nixosConfiguration's `specialArgs`:
```nix
users = [
  (import ./users/egor.nix)
  (import ./users/forge.nix)
];
```
Each user file is a simple attrset: `{ name = "egor"; homedir = "/home/egor"; stateVersion = "22.05"; }`.

- **Identity.** `home.nix` generates the base `home-manager.users.<name>` entry (identity only) for each user.
- **System accounts.** Role files generate `users.users.<name>` by mapping the `forAllUsers` helper over the `users` list.
- **Module fan-out.** Each NixOS module applies its `hm.nix` to **all users** through the `forAllUsers` helper. The active role determines which modules are enabled, and every enabled module configures every declared user automatically.
- **Per-user profiles.** A user's optional `homeModules` (in `users/<name>.nix`) lists home-manager profiles from `profiles/` to attach to **that one user**. This is the per-user complement to `forAllUsers`: `forAllUsers` configures every user, `homeModules` configures a single user.

### Dual Desktop Role Design

There are two parallel desktop roles that can be swapped in `hosts/<hostname>/configuration.nix`:

| Role | Module | Status |
|---|---|---|
| `role-x11-desktop-config.nix` | `modules/desktop-x11/` | Stable — i3 window manager on X11 |
| `role-wayland-desktop-config.nix` | `modules/desktop-wayland/` | WIP — Hyprland on Wayland |

The desktop module is selected by importing the desired role in the host configuration. Both roles expose the same `my.desktop` option namespace (`my.desktop.enable`, `my.desktop.primaryScreen`), so host configurations do not change when switching roles.

`modules/desktop-x11/` contains i3 config, i3status config, and xrandr multi-monitor scripts. It sets no wallpaper.
`modules/desktop-wayland/` configures Hyprland, Waybar, pipewire audio, NVIDIA drivers for Wayland (PRIME sync, open kernel module), dunst notifications, GTK/cursor theming, and XDG MIME associations via home-manager. The wallpaper is runtime state, not configuration: `waypaper` picks it and Hyprland restores it on login with `waypaper --restore`.

### Theme System

Theme values (colors, fonts) are defined in `flake.nix` under `specialArgs` and passed to all modules. Modules receive `theme` as a module argument. The color scheme is One Dark; font is Inconsolata Nerd Font Mono.

### Custom Packages

`modules/st/` compiles the suckless `st` terminal from source with patches applied. Patches are `.diff` files in that directory; `my-patch.nix` generates the theme-colored config.h. (st is currently disabled in the wayland role; kitty is used instead.)

### Notable Config Details

- `fractal`: AMD/NVIDIA hybrid hardware (PRIME sync), Hyprland/Wayland, primary display `DP-4`, ext4 on `/dev/disk/by-label/NIXROOT`; two users: `egor` and `forge`
- `thinkpad`: Intel hardware, PostgreSQL 14 at `/data/postgresql`, portable GRUB install
- Both use `nixos-unstable` nixpkgs
- Sudo without password is configured for the `wheel` group
- SSH on `fractal` has password auth disabled

## Documentation conventions

These conventions govern prose in every Markdown file in this repository, except the working notes `NOTE.md` and `TODOS.md`.

### Formatting

**Unwrapped text.** Paragraphs must not be hard-wrapped. Each paragraph is a single physical line; soft-wrapping is left to the editor and renderer. Hard line breaks inside a paragraph are not permitted. Tables and code blocks keep their natural line structure.

### Writing tone & voice

The documentation reads as a precise technical reference for the configuration. Match this when editing or adding prose.

- **Third person, present/future tense, declarative and confident.** State what the configuration *does* and *will do*; never "I" or "we want to". For example: "The flake exposes one `nixosConfiguration` per host." / "A headless role will not enable the desktop module."
- **Bolded lead-in concept, then prose.** A new idea opens with a bold noun-phrase followed by explanation: `**Module ownership.** Each feature module owns both its NixOS and home-manager configuration.`, `**Role composition.**`, `**Multi-user fan-out.**`. In bullet lists the same pattern names a capability in bold: `**Self-contained editor:** The neovim module declares its own runtime tools.`
- **Normative keywords for requirements, often bolded.** Use *must* / *will* / *should* RFC-style: "Every host **must declare** `base.keyboard.layout`", "Feature modules **must keep** their home-manager configuration in `hm.nix`", "A host **should import** exactly one top-level role".
- **Explain the *why*.** Justify design decisions, frequently with a numbered rationale list: "This separation matters for several reasons: 1. Portability… 2. Single source of truth… 3. Layout parametrization…". Sections often close with a summarizing sentence ("In essence, a module enabled by a role configures every declared user automatically.").
- **Light technical flourish in overviews, precise in design sections.** Top-level overviews allow phrasing such as "single source of truth", "composable layers", and "lower maintenance overhead". Deeper design subsections remain dry and exact.
- **Domain-fluent.** Use the established Nix vocabulary unglossed: flake, derivation, NixOS module versus home-manager module, `specialArgs` / `extraSpecialArgs`, role, overlay, generation, activation, option namespace, `nixos-rebuild`, evaluation, and the `forAllUsers` helper.
- **Specifications are pinned with concrete examples** — Nix snippets, flake output attributes, module option assignments, and shell invocations — rather than described abstractly.

Avoid first person, casual register, hedging ("maybe", "probably"), emoji, and contractions in the document body.
