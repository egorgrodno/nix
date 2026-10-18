{
  config,
  lib,
  pkgs,
  forAllUsers,
  ...
}:

{
  environment.systemPackages =
    if config.base.isNixosSystem then
      with pkgs;
      [
        git
        gh
        glab
        tea
      ]
    else
      [ ];

  home-manager.users = forAllUsers {
    imports = [ ./hm.nix ];

    # What `gh auth setup-git` writes, except that the command records gh's
    # store path, which garbage collection deletes. Kept out of hm.nix, which
    # the standalone profiles share without installing gh.
    programs.git.settings.credential."https://github.com".helper = [
      ""
      "${lib.getExe pkgs.gh} auth git-credential"
    ];
  };
}
