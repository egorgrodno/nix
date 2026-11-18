{ pkgs, ... }:

let
  hallmack = pkgs.writeText "lesskey-hallmack" ''
    e back-line
    E back-line-force
    a forw-line
    A forw-line-force
  '';
in
{
  programs.less = {
    enable = true;
    # Takes the hallmack keys while `kb-layout` has that layout saved, checked
    # on every start.
    package = pkgs.symlinkJoin {
      name = "less";
      paths = [ pkgs.less ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/less --run '
          read -r layout 2>/dev/null </var/lib/keyboard-layout || true
          if [ "$layout" = hallmack ]; then export LESSKEYIN=${hallmack}; fi
        '
      '';
    };
  };
}
