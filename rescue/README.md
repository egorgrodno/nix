# Rescue stick

Build it with `nx-iso`, which lets in the SSH keys listed in the git-ignored `rescue/authorized_keys`. A direct `nix build` of `nixosConfigurations.rescue` yields a stick that refuses SSH. `nx-flash` writes the ISO over a whole USB stick, rebuilding it first if the store lost it: the minimal ISO does not boot from Ventoy.

The stick's `repair-boot` and `nx-install`, the flake's `install`, are those of the revision it was built from, which the login banner names. Rebuild the stick after changing either. `nx-install` clones the configuration from GitHub when it runs, so unpushed commits never reach an install.

Nothing written on the stick survives a reboot. With NIXROOT mounted at `/mnt`, the host's repository is `/mnt/etc/nixos`, and changes there persist. Edit and commit there as `nixos`, not root: `nixos` has uid 1000, the host admin's, so git accepts the repository and leaves no root-owned objects in it.

## SSH from a host

The stick announces itself as `rescue.local` and makes a new host key on every boot. This block in `~/.ssh/config.local` stops ssh from refusing the changed key:

```sshconfig
Host rescue.local
  User nixos
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```
