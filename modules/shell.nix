{
  environment.shellAliases =
    { cfgedit = "xdg-open /etc/nixos/configuration.nix";
      l = "ls -alh --group-directories-first --color=auto";
      ls = "ls --group-directories-first --color=auto";
      y = "xclip -selection c";
    };
}
