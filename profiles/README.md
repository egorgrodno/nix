# Profiles

**Profile.** A home-manager module for one account, the per-user counterpart to a role. A user's `homeModules` in `users/<name>.nix` attaches it; a host, a role or `forAllUsers` never imports one.

```nix
homeModules = [ ../profiles/work.nix ];
```

| Profile | Attached to | Holds |
|---|---|---|
| `work.nix` | `forge` | `gpclient`, `slack` on XWayland, `uv` |
