# NixOS Config

Nix flakes + home-manager configuration for `fractal` (desktop) and `thinkpad` (laptop).

## Fresh Install

### 1. Apply the configuration

```bash
sudo nixos-rebuild switch --flake /etc/nixos#fractal-wayland
```

### 2. Set up Claude Code

Create `~/.claude/settings.json` with the status line configuration:

```bash
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "npx ccusage statusline --context-low-threshold 50 --context-medium-threshold 85",
    "padding": 0
  }
}
EOF
```

This configures the Claude Code status line to show token usage via `ccusage`.

### 3. Set up git identity

Git user identity is not stored in the flake. Create it once per user:

```bash
mkdir -p ~/.config/git
cat > ~/.config/git/config.local << 'EOF'
[user]
    name = Your Name
    email = your@email.com
EOF
```

This file is included automatically by the git module (`modules/git/hm.nix`).

## Standalone Neovim

Run neovim with this config on any system with Nix installed (no NixOS required):

```bash
nix run github:egorgrodno/nix#neovim           # qwerty layout
nix run github:egorgrodno/nix#neovim-hallmack  # hallmack layout
```

Packer installs plugins on first launch. LSP servers are not bundled — install them separately or via home-manager.

## Hosts

| Config | Host | Role |
|---|---|---|
| `fractal-wayland` | fractal desktop | Hyprland/Wayland, users: hy + egor |
| `fractal` | fractal desktop | i3/X11, user: egor |
| `thinkpad` | ThinkPad laptop | i3/X11, user: egor |

## Common Commands

```bash
nxs   # nixos-rebuild switch
nxc   # nixos-rebuild build  (build without activating)
nxb   # nixos-rebuild boot   (build + add boot entry)
nxt   # nixos-rebuild test   (no boot entry)
nxu   # nix flake update
```
