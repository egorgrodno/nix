{ config, pkgs, username, ... }:

{
  environment.systemPackages =
    if config.base.isNixosSystem
      then [ pkgs.git ]
      else [];

  home-manager.users.${username} = {
    programs.git = {
      enable = true;
      package = pkgs.gitSVN;
      diff-so-fancy.enable = true;
      userName = "Egor Zhyh";
      userEmail = "egor990095@gmail.com";
      ignores = [ "*.swp" "*node_modules*" "build" "dist" ];
      aliases = {
        co = "checkout";
        cm = "commit";
        cma = "commit --amend --no-edit";
        l = "log";
        lp = "log --graph --oneline --decorate";
        b = "branch";
        a = "add";
        r = "reset";
        s = "status -s";
        d = "diff";
        ds = "diff --stat";
        dc = "diff --cached";
        dcs = "diff --cached --stat";
        wip = "commit -m \"WIP\" --no-verify";
        pf = "push --force-with-lease";
        ls-conflicts = "diff --name-only --diff-filter=U --relative";
      };
      extraConfig = {
        core.autocrlf = false;
      };
    };
  };
}
