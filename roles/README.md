# Roles

**Role.** A NixOS module that bundles related configuration, so a host pulls in a whole capability through one import. Configuration for one user goes in a profile instead; see `profiles/README.md`.

## Foundation

`role-base-config.nix` declares the `base.*` options, mounts `/` and `/boot` by label, and writes the chassis to `/etc/machine-info`. Every top-level role **must** import it. It imports `role-laptop.nix`, which `base.isLaptop` turns on: power profiles, profile switching and the charge limit (`modules/power`), and lid close suspending as idle does.

## Aspect roles

Single-concern bundles, imported by a top-level role or directly by a host.

| Role | What it turns on |
|---|---|
| `role-locale-config.nix` | `Europe/Amsterdam`, `en_US.UTF-8`. |
| `role-network-config.nix` | NetworkManager with its OpenVPN plugin, and the firewall. |
| `role-print.nix` | CUPS (`brlaser`) and Avahi mDNS. |
| `role-devtools.nix` | `git`, `direnv`, `less`, `neovim`, `devtools`, `ripgrep`, `nixtools`, `extools`, `claude`. |
| `role-nextcloud-client.nix` | Nextcloud client and a per-user sync service. |
| `role-vm-host.nix` | VirtualBox host; blacklists the KVM modules, adds users to `vboxusers`. No host imports it, so no build checks it. |
| `role-docker.nix` | Docker, with `dockerd` left down at boot; adds `admin` users to `docker`. |

## Top-level roles

A host **must** import exactly one.

| Role | Stack |
|---|---|
| `role-desktop-config.nix` | Hyprland on Wayland (`modules/desktop`), the Craft apps (`modules/craft`), network, locale, devtools and print, and an account per user through `forAllUsers`. |
| `role-headless-config.nix` | `base.isHeadless` and `qwerty`, with no GUI and no accounts. No host imports it, so no build checks it. |

## Adding a host

The installer writes a new host; see the root `README.md`. By hand:

1. Create `hosts/<host>/` with `host.nix` (`users`, `stateVersion`), `configuration.nix`, and `hardware-configuration.nix` without `fileSystems`. At least one of the users needs `admin = true` in `users/<name>.nix`, or nobody can sudo.
2. Import a top-level role from `configuration.nix`. Role selection **must not** live in the flake.
3. Set `base.keyboard.layout`, which the desktop role defaults to `qwerty`. On a laptop, set `base.isLaptop`.
4. `git add` the directory: the flake sees only tracked files.
