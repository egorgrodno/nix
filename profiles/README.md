# Profiles

**Profile.** A profile is a home-manager module that adds a bundle of user-level configuration to a single account. Profiles are the per-user counterpart to roles: where a role composes system-level (NixOS) configuration for a host, a profile composes home-manager configuration for one user.

## How a profile is attached

A profile is **not** imported by a host or a role. It is listed in a user's `homeModules` in `users/<name>.nix`, and `home.nix` imports it into that user's home-manager configuration:

```nix
# users/forge.nix
{
  name = "forge";
  homedir = "/home/forge";
  stateVersion = "24.05";
  homeModules = [ ../profiles/work.nix ];
}
```

This is the deliberate complement to the `forAllUsers` helper. **`forAllUsers`** applies a feature module to *every* user on a host; **`homeModules`** applies a profile to *one* user. A profile therefore **must not** be imported into a host or a role, and it **must not** be applied through `forAllUsers`.

## Profiles

| Profile | Purpose |
|---|---|
| `work.nix` | Work tooling for a single account: `gpclient`, `slack` (forced onto XWayland), and `uv`, plus a GlobalProtect (`globalprotectcallback`) URL handler registered through `xdg.desktopEntries` and `xdg.mimeApps`. Attached to the `forge` user. |

## Adding a new profile

A new profile is an ordinary home-manager module at `profiles/<name>.nix`. It sets only home-manager options (`home.*`, `programs.*`, `xdg.*`) and **must not** set NixOS options. It is activated by adding it to the `homeModules` list of every user that should receive it.
