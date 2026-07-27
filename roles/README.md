# Roles

**Role.** A role is a composable NixOS module that bundles related configuration so that a host, or another role, pulls in an entire capability through a single import. Roles sit between hosts and feature modules:

```
flake.nix
  └── hosts/<host>/configuration.nix      hardware + which top-level role
        └── roles/role-*.nix              bundles of modules + option values
              └── modules/*               reusable feature modules
```

This layering keeps a host small and a feature module reusable: a host declares only its hardware and a single role, while behavior is composed from single-concern modules underneath.

Roles are ordinary NixOS modules and receive `specialArgs` (`users`, `forAllUsers`, `theme`, `pkgs-unstable`, `inputs`). Per-user home-manager configuration is a separate layer, attached through a user's `homeModules` rather than through a role; see `profiles/README.md`.

## The role layers

### Foundation

| Role | Purpose |
|---|---|
| `role-base-config.nix` | Declares the `base.*` option contract: `isNixosSystem`, `isDesktop`, `isHeadless`, `keyboard.layout` (`qwerty`\|`hallmack`, **required**), and `keyboard.swapCapsEscape`. It asserts that exactly one of `isDesktop`/`isHeadless` is set, and forwards `keyboardLayout` and `isDesktop` to home-manager through `extraSpecialArgs`. Every top-level role **must** import it. |

### Aspect roles

**Aspect roles** are small, single-concern bundles. They are imported by the top-level desktop and headless roles, not by hosts directly.

| Role | What it turns on |
|---|---|
| `role-locale-config.nix` | Timezone (`Europe/Amsterdam`) and the `en_US.UTF-8` locale. |
| `role-network-config.nix` | `networkmanager`, the firewall, and static `/etc/hosts` entries. |
| `role-print.nix` | CUPS printing (`brlaser`) and Avahi mDNS discovery. |
| `role-devtools.nix` | Imports the developer feature modules: `git`, `less`, `neovim`, `devtools`, `ripgrep`, `nixtools`, `extools`, `claude`. |
| `role-nextcloud-client.nix` | Nextcloud desktop client and a per-user sync `systemd` service (home-manager). |
| `role-vm-host.nix` | VirtualBox host: blacklists the KVM modules, enables the host extensions, and adds every declared user to `vboxusers`. |

### Top-level roles

**Top-level roles** are imported by a host, which **must** select exactly one. Each imports the foundation plus the aspect roles it needs, sets the `base.*` flags, creates the system user accounts (`users.users`, via `forAllUsers`), and enables the matching desktop module.

| Role | Stack |
|---|---|
| `role-x11-desktop-config.nix` | i3 on X11 (`modules/desktop-x11`). Pulls in network, locale, devtools, nextcloud, print, and vm-host. **Stable.** |
| `role-wayland-desktop-config.nix` | Hyprland on Wayland (`modules/desktop-wayland`). Pulls in network, locale, devtools, and print; nextcloud and vm-host are currently commented out. **WIP.** |
| `role-headless-config.nix` | No GUI: `base.isHeadless`, `qwerty`, and kitty terminfo. Intended for server and SSH-only use. |

**Namespace stability.** Both desktop roles expose the same `my.desktop.*` option namespace (`my.desktop.enable`, `my.desktop.primaryScreen`, …), so switching a host between X11 and Wayland is a single change to its role import.

## How a host wires in a role

A host imports its top-level role in `hosts/<host>/configuration.nix`. The flake's `nixosConfigurations` entry imports only the host file and assembles that host's `users` and `specialArgs`; role selection **must** live in the host configuration, not in the flake.

- **`fractal`** imports `role-wayland-desktop-config.nix`.
- **`thinkpad`** imports `role-x11-desktop-config.nix`.

## Adding a new host

A new host requires the following:

1. **Host files.** `hosts/<host>/configuration.nix` and `hosts/<host>/hardware-configuration.nix` define the machine.
2. **Top-level role.** `hosts/<host>/configuration.nix` imports an existing top-level role, or a new role that imports `role-base-config.nix`.
3. **Required options.** The host **must** set `base.keyboard.layout` and the desktop option `my.desktop.primaryScreen`.
4. **Registration.** The host is registered under `nixosConfigurations` in `flake.nix` with its `users` list, which drives both `users.users` and `home-manager.users` through the `forAllUsers` helper.

## Adding a new aspect role

A new aspect role is an ordinary NixOS module at `roles/role-<name>.nix`. It imports the feature modules it needs from `../modules/...` and/or sets the options those modules expose, and it **must** be added to the `imports` list of every top-level role that should include it.
