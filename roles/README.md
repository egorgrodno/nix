# Roles

**Role.** A composable NixOS module that bundles related configuration, so a host pulls in a whole capability through one import.

```text
flake.nix
  └── hosts/<host>/configuration.nix      hardware + one top-level role
        └── roles/role-*.nix              module bundles + option values
              └── modules/*               reusable feature modules
```

Roles receive `specialArgs` (`users`, `forAllUsers`, `theme`, `fontPackages`, `inputs`). Per-user home-manager configuration is attached through a user's `homeModules` instead; see `profiles/README.md`.

## Foundation

| Role | Purpose |
|---|---|
| `role-base-config.nix` | Declares the `base.*` contract — `isNixosSystem`, `isDesktop`, `isHeadless`, `isLaptop`, `hibernate`, `keyboard.layout` (`qwerty`\|`hallmack`, **required**), `keyboard.swapCapsEscape`. Asserts exactly one of `isDesktop`/`isHeadless`, and swap wherever `hibernate` is set. Forwards `keyboardLayout` and `isDesktop` to home-manager. Pins the chassis in `/etc/machine-info` to `laptop` or `desktop` by `isLaptop`, and imports `role-laptop.nix`. Mounts `/` and `/boot` by the `NIXROOT` and `NIXBOOT` labels. Every top-level role **must** import it. |

## Aspect roles

Single-concern bundles, imported by a top-level role or directly by a host.

| Role | What it turns on |
|---|---|
| `role-locale-config.nix` | `Europe/Amsterdam`, `en_US.UTF-8`. |
| `role-network-config.nix` | NetworkManager with its OpenVPN plugin, and the firewall. |
| `role-print.nix` | CUPS (`brlaser`) and Avahi mDNS. |
| `role-devtools.nix` | `git`, `direnv`, `less`, `neovim`, `devtools`, `ripgrep`, `nixtools`, `extools`, `claude`. |
| `role-nextcloud-client.nix` | Nextcloud client and a per-user sync service. |
| `role-vm-host.nix` | VirtualBox host; blacklists the KVM modules, adds users to `vboxusers`. |
| `role-docker.nix` | Docker, with `dockerd` left down at boot; adds `admin` users to `docker`. |
| `role-laptop.nix` | Turned on by `base.isLaptop`: power profiles, profile switching and the charge limit (`modules/power`), and the idle suspend on lid close, `suspend-then-hibernate` under `base.hibernate`. |

## Top-level roles

A host **must** import exactly one. Each pulls in the foundation plus the aspect roles it needs, sets `base.*`, creates `users.users` through `forAllUsers`, and enables its desktop module.

| Role | Stack |
|---|---|
| `role-desktop-config.nix` | Hyprland on Wayland (`modules/desktop`) and the Craft apps (`modules/craft`). Network, locale, devtools, print; nextcloud and vm-host are commented out. |
| `role-headless-config.nix` | No GUI: `base.isHeadless` and `qwerty`. Servers and SSH-only use; no host imports it at present. |

**Hardware stays with the host.** A role enables the stack; the host declares the screens (`my.desktop.primaryScreen`, `primaryMode`, `extraMonitors`) and the graphics driver, so two machines with different GPUs and panels share a role unchanged.

## Wiring a host

`hosts/<host>/configuration.nix` imports the role. The flake finds the host by its directory, imports only `configuration.nix`, and builds `users` and `specialArgs` from `host.nix`; role selection **must not** live in the flake. `fractal` and `thinkpad` both import `role-desktop-config.nix`.

## Adding a host

1. Create `hosts/<host>/` with `host.nix` (`users`, `stateVersion`), `configuration.nix`, and `hardware-configuration.nix` without `fileSystems`.
2. Import a top-level role, or a new one that imports `role-base-config.nix`.
3. Set `base.keyboard.layout` and `my.desktop.primaryScreen`.
4. `git add` the directory: the flake sees only tracked files.

## Adding an aspect role

A module at `roles/role-<name>.nix` that imports the feature modules it needs or sets their options. It **must** be added to the `imports` of every top-level role or host that should include it.
