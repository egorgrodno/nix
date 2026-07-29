# Roles

**Role.** A composable NixOS module that bundles related configuration, so a host pulls in a whole capability through one import.

```
flake.nix
  └── hosts/<host>/configuration.nix      hardware + one top-level role
        └── roles/role-*.nix              module bundles + option values
              └── modules/*               reusable feature modules
```

Roles receive `specialArgs` (`users`, `forAllUsers`, `theme`, `fontPackages`, `inputs`). Per-user home-manager configuration is attached through a user's `homeModules` instead; see `profiles/README.md`.

## Foundation

| Role | Purpose |
|---|---|
| `role-base-config.nix` | Declares the `base.*` contract — `isNixosSystem`, `isDesktop`, `isHeadless`, `keyboard.layout` (`qwerty`\|`hallmack`, **required**), `keyboard.swapCapsEscape`. Asserts exactly one of `isDesktop`/`isHeadless`, and forwards `keyboardLayout` and `isDesktop` to home-manager. Every top-level role **must** import it. |

## Aspect roles

Single-concern bundles, imported by top-level roles rather than by hosts.

| Role | What it turns on |
|---|---|
| `role-locale-config.nix` | `Europe/Amsterdam`, `en_US.UTF-8`. |
| `role-network-config.nix` | NetworkManager and the firewall. |
| `role-print.nix` | CUPS (`brlaser`) and Avahi mDNS. |
| `role-devtools.nix` | `git`, `direnv`, `less`, `neovim`, `devtools`, `ripgrep`, `nixtools`, `extools`, `claude`. |
| `role-nextcloud-client.nix` | Nextcloud client and a per-user sync service. |
| `role-vm-host.nix` | VirtualBox host; blacklists the KVM modules, adds users to `vboxusers`. |

## Top-level roles

A host **must** import exactly one. Each pulls in the foundation plus the aspect roles it needs, sets `base.*`, creates `users.users` through `forAllUsers`, and enables its desktop module.

| Role | Stack |
|---|---|
| `role-desktop-config.nix` | Hyprland on Wayland (`modules/desktop`). Network, locale, devtools, print; nextcloud and vm-host are commented out. |
| `role-headless-config.nix` | No GUI: `base.isHeadless` and `qwerty`. Servers and SSH-only use; no host imports it at present. |

**Hardware stays with the host.** A role enables the stack; the host declares the screens (`my.desktop.primaryScreen`, `primaryMode`, `extraMonitors`) and the graphics driver, so two machines with different GPUs and panels share a role unchanged.

## Wiring a host

`hosts/<host>/configuration.nix` imports the role. The flake imports only the host file and assembles its `users` and `specialArgs`; role selection **must not** live in the flake. `fractal` and `thinkpad` both import `role-desktop-config.nix`.

## Adding a host

1. Write `hosts/<host>/configuration.nix` and `hardware-configuration.nix`.
2. Import a top-level role, or a new one that imports `role-base-config.nix`.
3. Set `base.keyboard.layout` and `my.desktop.primaryScreen`.
4. Register under `nixosConfigurations` in `flake.nix` with a `users` list.

## Adding an aspect role

A module at `roles/role-<name>.nix` that imports the feature modules it needs or sets their options. It **must** be added to the `imports` of every top-level role that should include it.
