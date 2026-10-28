# A pre-push hook: refuses the push when gitleaks finds a secret in a commit
# the remote does not have yet. git runs it as
# `git-secret-scan <allowlist dir> <remote> <url>`, the pushed refs on stdin.
#
# The pusher may be a fleet worker, so nothing that can silence a finding is
# read from the repository or the environment.

set -euo pipefail

allowlists=$1
remote=$2

include=()
exclude=()
while read -r _ local_sha _ remote_sha; do
  # A delete pushes nothing.
  [[ $local_sha =~ ^0+$ ]] && continue
  include+=("$local_sha")
  # A remote sha this clone lacks cannot be excluded by name; --not --remotes
  # below still excludes whatever of the remote it has fetched.
  if [[ ! $remote_sha =~ ^0+$ ]] && git cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
    exclude+=("^$remote_sha")
  fi
done
[ ${#include[@]} -eq 0 ] && exit 0

# gitleaks splits --log-opts on single spaces, so no part may be empty; shas
# and remote names hold no spaces.
range=("${include[@]}" "${exclude[@]}" --not "--remotes=$remote")
if ! git rev-list --quiet "${range[@]}"; then
  echo "secret-scan: cannot list the pushed commits, so the push is refused." >&2
  exit 1
fi

{
  read -r common
  read -r GIT_DIR
} < <(git rev-parse --path-format=absolute --git-common-dir --absolute-git-dir)
export GIT_DIR
top=${common%/.git}
key=${top#/}
key=${key//\//-}
ignore=$allowlists/$key.gitleaksignore
config=$allowlists/$key.toml
[ -f "$config" ] || config=$DEFAULT_CONFIG

# gitleaks reads .gitleaksignore and .gitleaks.toml from the directory it scans
# and from the cwd, so it runs in an empty one, its git reaching the repository
# through GIT_DIR.
empty=$(mktemp -d)
trap 'rmdir "$empty"' EXIT
cd "$empty"

status=0
out=$(gitleaks git . \
  --log-opts="${range[*]}" \
  --config="$config" \
  --gitleaks-ignore-path="$ignore" \
  --ignore-gitleaks-allow \
  --no-banner --no-color --log-level=warn --verbose --redact=60 \
  --exit-code=2 2>&1) || status=$?
[ -n "$out" ] && printf '%s\n' "$out" >&2
# gitleaks 8.30 exits 0 when its git fails, logging the scan as partial.
[[ $status -eq 0 && $out == *"partial scan"* ]] && status=1

case $status in
0) exit 0 ;;
2)
  cat >&2 <<MSG

secret-scan: refused the push to $remote: gitleaks found the secrets above in
commits $remote does not have yet. Remove them from history, not only from the
latest commit. For a finding you have checked and know to be harmless, add its
Fingerprint line to
  $ignore
or push once with \`git push --no-verify\`.
MSG
  ;;
*) echo "secret-scan: gitleaks failed, so the push is refused." >&2 ;;
esac
exit 1
