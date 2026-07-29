# NixOS Config

Nix flakes and home-manager configuration for the `fractal` desktop and the `thinkpad` laptop.

## Fresh Install

### 1. Apply the configuration

```bash
sudo nixos-rebuild switch --flake /etc/nixos#fractal
```

### 2. Set up Claude Code

The status line reads its command from `~/.claude/settings.json` and shows token usage through `ccusage`:

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

### 3. Set up git identity

Git identity is not stored in the flake and **must** be created once per user:

```bash
mkdir -p ~/.config/git
cat > ~/.config/git/config.local << 'EOF'
[user]
    name = Your Name
    email = your@email.com
EOF
```

The git module (`modules/git/hm.nix`) includes this file automatically.

## Standalone Neovim

The `neovim-qwerty` and `neovim-hallmack` home-manager profiles install this neovim configuration, together with git, on any non-NixOS machine that has Nix and home-manager:

```bash
home-manager switch --impure --flake github:egorgrodno/nix#neovim-qwerty    # qwerty layout
home-manager switch --impure --flake github:egorgrodno/nix#neovim-hallmack  # hallmack layout
```

`--impure` is **required**: the profile reads `$USER` and `$HOME` to place itself on whatever account invokes it, and pure evaluation aborts with a message naming the variable. The alternative is to set `mkNeovimHome`'s `username` and `homeDirectory` explicitly in `flake.nix`.

The profile is self-contained: the neovim module bundles its own runtime tools and language servers (`ripgrep`, `fd`, `nodejs`, the LSP servers). Packer installs plugins on first launch, so `:PackerSync` **must** be run once after the first `nvim` start.

## Hosts

| Config | Host | Role |
|---|---|---|
| `fractal` | fractal desktop | Hyprland/Wayland, users: egor + forge |
| `thinkpad` | ThinkPad laptop | Hyprland/Wayland, user: egor |

## Common Commands

```bash
nxs   # nixos-rebuild switch
nxc   # nixos-rebuild build  (build without activating)
nxb   # nixos-rebuild boot   (build + add boot entry)
nxt   # nixos-rebuild test   (no boot entry)
nxu   # nix flake update
```
