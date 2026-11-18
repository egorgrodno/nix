# Applies a home-manager module, or a function `u: module` for one that needs
# per-user values like `u.homedir`, to every user.
lib: users: f:
lib.listToAttrs (
  map (u: {
    name = u.name;
    value = if lib.isFunction f then f u else f;
  }) users
)
