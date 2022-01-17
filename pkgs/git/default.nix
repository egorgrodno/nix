{ pkgs, username, ... }:

{
  home-manager.users.${username} = {
    programs.git = {
      enable = true;
      userName = "Egor Zhyh";
      userEmail = "egor990095@gmail.com";
      ignores = [ "*.swp" "*node_modules*" ];
      aliases = {
        co = "checkout";
        cm = "commit";
        l = "log";
        b = "branch";
        a = "add";
        r = "reset";
        s = "status -s";
        afp = "!git commit --amend --no-edit && git push -f";
        d = "diff";
        ds = "diff --stat";
        dc = "diff --cached";
        dcs = "diff --cached --stat";
        wip = "commit -m \"WIP\" --no-verify";
      };
    };
  };
}
