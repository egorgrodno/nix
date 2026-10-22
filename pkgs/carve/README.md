# carve

Splits the working tree's changes into commits, hunk by hunk, from one plan. An agent splitting a large diff uses it instead of hand-writing patches for `git apply --cached` and stashing to test each intermediate state.

## Install

```sh
nix run github:egorgrodno/nix#carve -- map
nix profile install github:egorgrodno/nix#carve
```

On this flake's hosts, `modules/git` installs it for every user.

## Use

```sh
carve map                        # one line per hunk, under its file
carve show a3f1c2 modules/       # hunks, their changed lines numbered
carve apply --dry-run plan.json  # each commit's paths and line counts
carve apply plan.json            # or the plan on stdin
```

```text
modules/desktop/hm.nix  -1 +3
  a3f1c2     41  -1 +1     col.active_border = "rgb(${theme.blue})";
  9c02aa    120  +2        layerrule = order 1, notifications
```

A plan gives each commit a message and the hunks it takes, by ID, line range or path. `carve apply -h` documents the format.

```json
{
  "commits": [
    {"message": "make the focused-window border solid", "take": ["a3f1c2"]},
    {"message": "put the notification popups under the panels", "take": ["9c02aa", "modules/quickshell/"]}
  ],
  "leave": ["TODO.md"]
}
```

## Guarantees

- **The working tree is never touched.** Each commit is built in a scratch worktree from HEAD and the hunks the plan takes. The index ends matching the new HEAD.
- **All or nothing.** The branch moves only once every commit passes, and only while HEAD and the working tree still hold what carve read.
- **Hooks judge the commit.** Each commit is a real `git commit` over its own content, so a pre-commit hook sees what is committed, not the working file. A hook that fixes a file, failing or not, runs again over its fix, which must then pass unchanged; one that fails without a fix stops the run. A fix to an interim version of a file stands until a later commit replaces that version. A fix to a file's final version stops the run, and the error names the `git diff` that shows it.
- **Every line is accounted for.** Each changed line, untracked files included, lands in exactly one commit or in `leave`. A plan that misses or doubles one is refused, with every problem listed at once.
- **IDs are stable.** An ID derives from the hunk's path and content, so an edit elsewhere keeps it.

## Hunks

A hunk is a `git diff -U0` hunk: a run of changed lines without context, so any subset of hunks applies to HEAD. `show` interleaves a hunk's lines, each new line after the old line it most resembles. `carve apply -h` covers partial takes and overrides.

## Limits

Submodules and nested repositories are refused. A deletion, a binary, a symlink and a file whose filters change its content are taken whole. A mode change is an item of its own, apart from the file's hunks.

## Development

`go test ./...` runs the tests, each in a repository of its own. `nix build .#carve` runs them in the sandbox, and `nix flake check` with the rest of the flake.
