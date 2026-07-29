# Profiles

**Profile.** A home-manager module that adds user-level configuration to a single account — the per-user counterpart to a role.

## Attaching a profile

A profile is listed in a user's `homeModules`. It is never imported by a host or a role, and never applied through `forAllUsers`:

```nix
# users/forge.nix
{
  name = "forge";
  homedir = "/home/forge";
  stateVersion = "24.05";
  homeModules = [ ../profiles/work.nix ];
}
```

`forAllUsers` applies a feature module to every user on a host; `homeModules` applies a profile to one.

## Profiles

| Profile | Purpose |
|---|---|
| `work.nix` | Work tooling for one account: `gpclient`, `slack` (forced onto XWayland), `uv`. Attached to `forge`. |

## Adding a profile

An ordinary home-manager module at `profiles/<name>.nix`. It sets only home-manager options (`home.*`, `programs.*`, `xdg.*`) and **must not** set NixOS options. Activate it by adding it to a user's `homeModules`.
