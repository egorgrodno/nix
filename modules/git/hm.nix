{ pkgs, config, ... }:

{
  programs.git = {
    enable = true;
    package = pkgs.gitSVN;
    includes = [
      { path = "${config.xdg.configHome}/git/config.local"; }
      # Conditional rather than a global core.hooksPath, which would point every
      # other checkout at a hook directory it does not have. The path is absolute
      # because git resolves hooksPath against the cwd, not the repository root.
      {
        condition = "gitdir:/etc/nixos/";
        contents.core.hooksPath = "/etc/nixos/.githooks";
      }
    ];
    ignores = [
      "*.swp"
      "*node_modules*"
      "build"
      "dist"
    ];
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
