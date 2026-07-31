{ pkgs, config, ... }:

{
  programs.git = {
    enable = true;
    package = pkgs.gitSVN;
    includes = [{ path = "${config.xdg.configHome}/git/config.local"; }];
    ignores = [ "*.swp" "*node_modules*" "build" "dist" ];
    settings = {
      alias = {
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
      core.autocrlf = false;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
