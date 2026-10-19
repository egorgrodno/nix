# Pins every app keyed in sources.json to its latest GitHub release: the
# version and the hash of its Linux x86_64 tarball. A new app enters as a key
# with an empty object.

sources=${1:-/etc/nixos/modules/craft/sources.json}

json=$(cat "$sources")
for app in $(jq -r 'keys[]' <<<"$json"); do
  # The redirect names the tag, without spending the API's anonymous rate limit.
  tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/storytold/$app/releases/latest")
  version=${tag##*/v}
  if [ "$(jq -r --arg app "$app" '.[$app].version // ""' <<<"$json")" = "$version" ]; then
    echo "$app $version"
    continue
  fi
  url=https://github.com/storytold/$app/releases/download/v$version/$app-$version-linux-x86_64.tar.gz
  hash=$(nix store prefetch-file --json "$url" | jq -r .hash)
  json=$(jq --arg app "$app" --arg v "$version" --arg h "$hash" '.[$app] = {version: $v, hash: $h}' <<<"$json")
  echo "$app -> $version"
done
jq -S . <<<"$json" >"$sources"
