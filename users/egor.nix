{ lib }:

import
  ./shared.nix
  { inherit lib;
    username = "egor";
    email = "egor990095@gmail.com";
    name = "Egor Zhyh";
    homefiles = true;
    gitconfig = true;
  }
