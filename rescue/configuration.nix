# The rescue stick: the minimal installer, with this flake's tools for
# repairing or reinstalling a host. nx-iso builds it.
{
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}:

let
  inherit (inputs) self;
  flakePackages = self.packages.${pkgs.stdenv.hostPlatform.system};
  revision = "${
    self.shortRev or self.dirtyShortRev or "an unknown revision"
  } (${lib.concatStringsSep "-" (builtins.match "(....)(..)(..).*" self.lastModifiedDate)})";

  # Which nvim-<layout> `nvim` opens, for every user until the next boot.
  layoutFile = "/run/nvim-layout";

  # The flake's `install` would shadow coreutils' install.
  nxInstall = pkgs.runCommand "nx-install" { } ''
    mkdir -p $out/bin
    ln -s ${lib.getExe flakePackages.install} $out/bin/nx-install
  '';

  # vi and vim as well, as on the hosts, over the ISO's own vim.
  nvim = lib.hiPrio (
    pkgs.runCommand "nvim" { } ''
      mkdir -p $out/bin
      for name in nvim vi vim; do
        ln -s ${pkgs.writeShellScript "nvim" ''
          layout=$(cat ${layoutFile} 2>/dev/null)
          exec nvim-''${layout:-qwerty} "$@"
        ''} $out/bin/$name
      done
    ''
  );

  nvimLayout = pkgs.writeShellApplication {
    name = "nvim-layout";
    runtimeInputs = [ pkgs.gum ];
    text = ''
      layout=$(gum choose --header "Keyboard layout of nvim" --selected "$(cat ${layoutFile})" qwerty hallmack)
      echo "$layout" >${layoutFile}
    '';
  };

  rescueHelp = pkgs.writeShellApplication {
    name = "rescue-help";
    runtimeInputs = [
      pkgs.gawk
      pkgs.iproute2
    ];
    text = ''
      echo "NixOS rescue stick, built from ${revision}"
      echo
      cat ${./cheatsheet.txt}
      echo

      mapfile -t addresses < <(ip -4 -br address show scope global | awk '{ sub(/\/.*/, "", $3); print "nixos@" $3 }')
      if ((''${#addresses[@]})); then
        echo "SSH in as nixos@rescue.local or ''${addresses[*]}; the host key changes every boot."
      else
        echo "No network yet: nmtui joins Wi-Fi, then rescue-help shows the address."
      fi

      # systemd's record of a hibernation, which the next boot resumes from.
      if [[ -e /sys/firmware/efi/efivars/HibernateLocation-8cf2644b-4b0b-428f-9387-6d876050dc67 ]]; then
        echo "This machine is hibernated. Mount its NIXROOT with -o ro,noload or not at all:"
        echo "resuming over a changed disk corrupts it. repair-boot offers to discard the session."
      fi
    '';
  };

  # As on the hosts, in modules/claude.
  claude = pkgs.writeShellScriptBin "claude" ''
    nix run github:sadjow/claude-code-nix -- "$@"
  '';
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix" ];

  isoImage.edition = "rescue";
  isoImage.appendToMenuLabel = " Rescue";

  networking.hostName = "rescue";
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  environment.etc.nixos.source = self.outPath;
  # It would copy a configuration.nix into /etc/nixos, which is the read-only flake.
  installer.cloneConfig = false;

  systemd.tmpfiles.rules = [ "f ${layoutFile} 0666 root root -" ];
  environment.variables.EDITOR = "nvim";

  # Every interactive login, the console's and SSH's alike, until a layout is chosen.
  programs.bash.loginShellInit = ''
    if [[ $- == *i* ]]; then
      rescue-help
      [[ -s ${layoutFile} ]] || nvim-layout || true
    fi
  '';

  environment.systemPackages = [
    flakePackages.repair-boot
    nxInstall
    rescueHelp
    nvim
    nvimLayout
    (pkgs.callPackage ../modules/neovim/standalone.nix { layout = "qwerty"; })
    (pkgs.callPackage ../modules/neovim/standalone.nix { layout = "hallmack"; })
    claude
    pkgs.gh
    pkgs.gum
    pkgs.btop
    pkgs.lm_sensors
    pkgs.rclone
  ];
}
