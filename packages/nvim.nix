{ pkgs, ... }:

{ environment.systemPackages = [ pkgs.neovim ];

  environment.variables =
    { VISUAL = "nvim";
    };

  programs.neovim =
    { enable = true;
      viAlias = true;
      vimAlias = true;
    };
}
