# Per-user setup after the first boot, for the state Nix leaves to each user:
# logins, identity, and plugin checkouts. Every step checks before it acts and
# skips what is done, so a rerun is safe.

forgejo=http://forgejo.home
teaLogin=forgejo
nixos=/etc/nixos
githubRepo=git@github.com:egorgrodno/nix.git
forgejoRepo=ssh://git@forgejo.home:30143/egor/nix.git
config=${XDG_CONFIG_HOME:-$HOME/.config}
me=$(id -un)

# A step exits with this status to report that nothing was left to do.
alreadyDone=100

summary=()
failed=0

die() {
  echo "  $*" >&2
  exit 1
}

skip() {
  echo "  $*"
  exit "$alreadyDone"
}

# Each step runs in a subshell with errexit on: called as an `if` condition,
# bash would ignore every failing command inside it.
step() {
  local title=$1 fn=$2 status
  gum style --bold "$title"
  set +e
  (
    set -e
    "$fn"
  )
  status=$?
  set -e
  case $status in
  0) summary+=("done     $title") ;;
  "$alreadyDone") summary+=("skipped  $title") ;;
  *)
    summary+=("FAILED   $title")
    failed=1
    ;;
  esac
}

sshDir() {
  if [[ $(stat -c %a "$HOME/.ssh" 2>/dev/null) == 700 && -e $HOME/.ssh/config.local ]]; then
    skip "$HOME/.ssh and its config.local are in place"
  fi
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  [[ -e $HOME/.ssh/config.local ]] || install -m 600 /dev/null "$HOME/.ssh/config.local"
}

# Trusted on first use, so the fingerprints are printed for a look.
knownHosts() {
  local file=$HOME/.ssh/known_hosts target host port name keys added=0
  for target in github.com:22 forgejo.home:30143; do
    host=${target%:*}
    port=${target#*:}
    name=$host
    [[ $port == 22 ]] || name="[$host]:$port"
    if ssh-keygen -F "$name" -f "$file" >/dev/null 2>&1; then
      continue
    fi
    keys=$(ssh-keyscan -p "$port" "$host" 2>/dev/null)
    [[ -n $keys ]] || die "$name did not answer ssh-keyscan"
    printf '%s\n' "$keys" >>"$file"
    ssh-keygen -lf - <<<"$keys" | sed 's/^/  /'
    added=1
  done
  ((added)) || skip "$file has github.com and [forgejo.home]:30143"
}

gitIdentity() {
  local file=$config/git/config.local name email
  if name=$(git config --file "$file" user.name 2>/dev/null) &&
    email=$(git config --file "$file" user.email 2>/dev/null); then
    skip "$name <$email>"
  fi
  name=$(gum input --prompt "Full name: ")
  email=$(gum input --prompt "Email: ")
  [[ -n $name && -n $email ]] || die "both a name and an email are required"
  mkdir -p "$(dirname "$file")"
  git config --file "$file" user.name "$name"
  git config --file "$file" user.email "$email"
}

github() {
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    skip "logged in to github.com"
  fi
  # With the SSH protocol, gh offers to generate ~/.ssh/id_ed25519 and uploads
  # the public key. gh waits for its browser command to exit, which a browser
  # it had to start does only once closed, so the browser starts in a unit of
  # its own.
  GH_BROWSER="uwsm app -t service --" gh auth login --hostname github.com --git-protocol ssh --web
}

forgejoLogin() {
  local method user secret
  if tea logins list --output json | jq -e --arg name "$teaLogin" 'any(.[]; .name == $name)' >/dev/null; then
    skip "tea already has the $teaLogin login"
  fi
  method=$(gum choose --header "Log in to $forgejo with" "access token" "user and password")
  # Secrets go through the environment, where other users cannot read them,
  # rather than the command line.
  if [[ $method == "access token" ]]; then
    secret=$(gum input --password --prompt "Token: ")
    GITEA_SERVER_TOKEN=$secret tea login add --name "$teaLogin" --url "$forgejo"
  else
    user=$(gum input --prompt "User: " --value "$me")
    secret=$(gum input --password --prompt "Password: ")
    GITEA_SERVER_PASSWORD=$secret tea login add --name "$teaLogin" --url "$forgejo" --user "$user"
  fi
}

forgejoHasKey() {
  tea api --login "$teaLogin" user/keys |
    jq -e --arg key "$1" 'any(.[]; .key | startswith($key))' >/dev/null
}

forgejoKey() {
  local pub=$HOME/.ssh/id_ed25519.pub key
  [[ -f $pub ]] || die "no $pub, which the GitHub step generates"
  key=$(cut -d' ' -f1,2 "$pub")
  if forgejoHasKey "$key"; then
    skip "$pub is on $forgejo"
  fi
  tea api --login "$teaLogin" --method POST user/keys \
    --field title="$me@$(uname -n)" --field key="$key" >/dev/null
  # tea's exit status does not reflect the HTTP status, so read the key back.
  forgejoHasKey "$key" || die "$forgejo did not accept $pub"
}

# In the login keyring, where the bar's Todoist module looks it up; without
# one the bar shows no Todoist.
todoistToken() {
  local token
  if secret-tool lookup service todoist >/dev/null 2>&1; then
    skip "the keyring holds a Todoist token"
  fi
  if ! gum confirm "Connect Todoist to the bar?"; then
    skip "no Todoist"
  fi
  echo "  The token is under Settings > Integrations > Developer at https://app.todoist.com/app/settings/integrations"
  token=$(gum input --password --prompt "Token: ")
  [[ -n $token ]] || die "no token given"
  printf %s "$token" | secret-tool store --label "Todoist API token" service todoist
  quickshell ipc call todoist refresh >/dev/null 2>&1 || true
}

neovimPlugins() {
  local compiled=$config/nvim/plugin/packer_compiled.lua
  if [[ -f $compiled ]]; then
    skip "packer has synced"
  fi
  # From $HOME: packer expands plugin names against the working directory, and
  # the config's wildignore drops anything under */tmp/*. The config also errors
  # on this first start, before its plugins exist, so the output is noise and
  # the compiled file is the evidence.
  cd "$HOME"
  gum spin --title "PackerSync" -- \
    nvim --headless -c 'autocmd User PackerComplete quitall' -c PackerSync || true
  [[ -f $compiled ]] || die "PackerSync did not finish; run nvim +PackerSync"
}

ownsNixos() {
  local owner
  owner=$(stat -c %U "$nixos")
  [[ $owner == "$me" ]] || skip "$nixos belongs to $owner"
}

nixosRemote() {
  ownsNixos
  if [[ $(git -C "$nixos" remote get-url origin 2>/dev/null) == "$githubRepo" &&
  $(git -C "$nixos" config --get-all remote.origin.pushurl) == "$(printf '%s\n' "$githubRepo" "$forgejoRepo")" ]]; then
    skip "origin fetches from GitHub and pushes to GitHub and Forgejo"
  fi
  if git -C "$nixos" remote get-url origin >/dev/null 2>&1; then
    git -C "$nixos" remote set-url origin "$githubRepo"
  else
    git -C "$nixos" remote add origin "$githubRepo"
  fi
  git -C "$nixos" config --unset-all remote.origin.pushurl || true
  git -C "$nixos" config --add remote.origin.pushurl "$githubRepo"
  git -C "$nixos" config --add remote.origin.pushurl "$forgejoRepo"
}

nixosPush() {
  local branch ahead
  ownsNixos
  branch=$(git -C "$nixos" symbolic-ref --short HEAD)
  git -C "$nixos" fetch --quiet origin
  if git -C "$nixos" rev-parse --verify --quiet "refs/remotes/origin/$branch" >/dev/null; then
    ahead=$(git -C "$nixos" rev-list --count "origin/$branch..HEAD")
  else
    ahead=$(git -C "$nixos" rev-list --count HEAD)
  fi
  ((ahead > 0)) || skip "$branch is not ahead of origin"
  gum confirm "Push $ahead commit(s) on $branch to GitHub and Forgejo?" || skip "push declined"
  git -C "$nixos" push origin "$branch"
}

[[ $EUID -ne 0 ]] || die "run as the user being set up, not as root"

step "SSH directory" sshDir
step "SSH known hosts" knownHosts
step "Git identity" gitIdentity
step "GitHub login and SSH key" github
step "Forgejo login" forgejoLogin
step "SSH key on Forgejo" forgejoKey
step "Todoist token" todoistToken
step "Neovim plugins" neovimPlugins
step "/etc/nixos remote" nixosRemote
step "Push /etc/nixos" nixosPush

echo
printf '%s\n' "${summary[@]}"
exit "$failed"
