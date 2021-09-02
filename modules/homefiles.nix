{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.homefiles;
  assertRelative = path: default: assert !(lib.strings.hasSuffix ".." path); default;
in
  {
    options.homefiles = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };

      users = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "affected users";
      };

      file = mkOption {
        default = {};
        type = with types; attrsOf (submodule {
          options = {
            path = mkOption {
              type = str;
              description = "path to link relative to user home directory";
            };
            content = mkOption {
              type = str;
              description = "file content";
            };
          };
        });
      };
    };

    config = mkIf cfg.enable {
      environment.etc =
        let
          mkFile = filename: { content, ... }:
            # assertRelative filename
            nameValuePair
              "homefiles/${filename}"
              { mode = "0444";
                text =
                  ''
                    # /etc/homefiles/${filename}: DO NOT EDIT -- this file has been generated automatically.

                    ${content}
                  '';
              };
        in
          mapAttrs' mkFile cfg.file;

      systemd.services.homefiles =
        let
          files = mapAttrs (key: value: assertRelative value.path value) cfg.file;
          mkLine = user: mapAttrsToList (key: value: "makelink \"${user}\" \"${key}\" \"${value.path}\"") files;
          lines = concatMap mkLine cfg.users;
          script = concatStringsSep "\n" lines;
        in
          { description = "Link files in home";
            wantedBy = [ "multi-user.target" ];
            script =
              ''
                function makelink() {
                  homefiles="/etc/homefiles"
                  home="/home/$1"
                  from="$homefiles/$2"
                  to=$(realpath -m -s "$home/$3")
                  dir=$(dirname $to)

                  if [[ $from != $homefiles* || $to != $home* || $dir != $home* ]]; then
                    echo "$1 $2 $3"
                    echo "invalid path"
                    exit 1
                  fi

                  if [[ $dir != $home && ! -d $dir ]]; then
                    ${pkgs.su}/bin/su $1 -c "mkdir -p $dir"
                  fi

                  if [[ -h $to ]]; then
                    rm $to
                  elif [[ -f $to ]]; then
                    mv $to "$to.save"
                  fi

                  ln -s $from $to
                }

                ${script}
              '';
          };
    };
  }
