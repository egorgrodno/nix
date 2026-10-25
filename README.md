# NixOS Config

Nix flakes and home-manager configuration for the `fractal` desktop and the `thinkpad` laptop.

## Fresh Install

### 1. Install

Boot a NixOS ISO in UEFI mode, connect to the network, and run:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run github:egorgrodno/nix#install
```

It asks every question first. The host is either one from `hosts/` to reinstall or a new one, for which it asks the layout, hardware and users, proposing the hardware it detects. It then writes and evaluates the host, and only after that asks for the disk:

| Disk mode | Effect |
|---|---|
| Wipe a disk | GPT with a 1 GiB `NIXBOOT` ESP and the rest ext4 `NIXROOT`. A disk with Windows on it is refused unless its device path is typed. |
| Reuse | Reformats `NIXROOT` and keeps `NIXBOOT` as it is. `fractal` **must** use it, since `nvme0n1` also holds Windows' D:. |

Typing the hostname starts the install. It ends by setting each user's password and leaving `/etc/nixos` as a clone owned by the first admin, with the host committed. A host needs at least one user with `admin = true` in `users/<name>.nix`.

### 2. Run nx-setup

Each user runs it once after the first login. It prompts for what it needs, skips what is already done, and ends with a summary, so a rerun is safe:

```bash
nx-setup
```

| Step | Effect |
|---|---|
| SSH directory | `~/.ssh` at mode 700, and an empty `~/.ssh/config.local` for private hosts, which the generated `~/.ssh/config` includes. |
| SSH known hosts | Scans `github.com` and `forgejo.home:30143` into `~/.ssh/known_hosts` and prints the fingerprints. |
| Git identity | `user.name` and `user.email` in `~/.config/git/config.local`, which the git module includes. |
| GitHub | `gh auth login` with the SSH protocol, which offers to generate `~/.ssh/id_ed25519` and upload it. |
| Forgejo | `tea login add` for `http://forgejo.home` with a token or a password, then uploads the SSH key. |
| Todoist | Optional. The API token in the login keyring, where the bar's Todoist module finds it. |
| Neovim | Headless `PackerSync`. |
| bosun | Makes `~/.local/state/bosun/master`, marks it trusted in `~/.claude.json`, and starts the `bosun` user service. It needs `~/.claude.json`, which `claude` writes on its first run. |
| `/etc/nixos` | For its owner only: `origin` fetches from GitHub and pushes to GitHub and Forgejo, and unpushed commits are pushed after a confirmation. |

## Repair the boot menu

A Windows update can remove GRUB's firmware entry. Boot a NixOS ISO in UEFI mode, connect to the network, and run:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run github:egorgrodno/nix#repair-boot
```

It mounts `NIXROOT` and `NIXBOOT`, reinstalls the bootloader from the installed generation without rebuilding, and lists the firmware entries. Offline, nearly the same by hand, without its care for initrd secrets:

```bash
sudo -i
mount /dev/disk/by-label/NIXROOT /mnt
mount -o umask=077 /dev/disk/by-label/NIXBOOT /mnt/boot
nixos-enter --root /mnt -c 'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot'
```

## Standalone Neovim

The `neovim-qwerty` and `neovim-hallmack` home-manager profiles install this neovim configuration, together with git, on any non-NixOS machine that has Nix and home-manager:

```bash
home-manager switch --impure --flake github:egorgrodno/nix#neovim-qwerty    # qwerty layout
home-manager switch --impure --flake github:egorgrodno/nix#neovim-hallmack  # hallmack layout
```

`--impure` is **required**: the profile reads `$USER` and `$HOME` to place itself on whatever account invokes it, and pure evaluation aborts with a message naming the variable. The alternative is to set `mkNeovimHome`'s `username` and `homeDirectory` explicitly in `flake.nix`.

The profile is self-contained: the neovim module bundles its own runtime tools and language servers (`ripgrep`, `fd`, `nodejs`, the LSP servers). Its plugins are not: Packer fetches them, so `:PackerSync` **must** be run once after the first `nvim` start.

## Common Commands

```bash
nxs   # nixos-rebuild switch
nxc   # nixos-rebuild build  (build without activating)
nxb   # nixos-rebuild boot   (build + add boot entry)
nxt   # nixos-rebuild test   (no boot entry)
nxu   # nix flake update, then craft-update
```
