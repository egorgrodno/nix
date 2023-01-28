{ pkgs, username, ... }:

{
  home-manager.users.${username} = {
    programs.git = {
      enable = true;
      package = pkgs.gitSVN;
      diff-so-fancy.enable = true;
      userName = "Egor Zhyh";
      userEmail = "egor990095@gmail.com";
      ignores = [ "*.swp" "*node_modules*" ];
      aliases = {
        co = "checkout";
        cm = "commit";
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
        afp = "!git commit --amend --no-edit && git push -f";
        ls-conflicts = "diff --name-only --diff-filter=U --relative";
      };
      extraConfig = {
        core.autocrlf = false;
      };
    };
  };
}
