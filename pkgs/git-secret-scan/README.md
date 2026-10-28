# git-secret-scan

A pre-push hook that runs gitleaks, with its default rules, over every commit the remote does not have yet. A finding refuses the push. A secret that a later commit removes still counts, since the history publishes it.

`modules/git` sets it as git's config-based hook `hook.secret-scan` for `pre-push`, in every user's global config. It runs in every repository, and the checkout's own pre-push hook still runs after it.

## Push past a finding

Check the finding first, then do one of these:

- **Once:** `git push --no-verify`. It also skips the repository's own pre-push hook.
- **For good:** add the finding's `Fingerprint:` line to the repository's allowlist. The refusal prints that file's path.

The allowlist is `~/.config/gitleaks/<key>.gitleaksignore`. `<key>` is the main checkout's path with its slashes turned into dashes: `etc-nixos`, `home-egor-Projects-bosun`. An optional `<key>.toml` replaces the rules. It must open with `[extend]` and `useDefault = true` to keep the default rules.

Both files and the bypass are for the user alone. Fleet sandboxes cannot write to `~/.config`, and bosun sends `--no-verify` and other hook overrides to the user. The scan ignores a repository's own `.gitleaksignore`, `.gitleaks.toml` and inline `gitleaks:allow` comments, because a worker could commit those.
