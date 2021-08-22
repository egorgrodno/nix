{ pkgs, ... }: 

let
  setuphome =
    pkgs.writeShellScriptBin
      "setuphome"
      ''
        if [[ -z $USER ]] || [[ -z $HOME ]] || [[ ! -d $HOME ]]; then
          exit 1
        fi

        read -p "Setup home for user $USER? [y/N]: " response

        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
          set -x
          ln -s /etc/home/xinitrc $HOME/.xinitrc
          mkdir -p $HOME/.config/zsh
          ln -s /etc/home/profile $HOME/.config/zsh/.zprofile
        else
          exit 1
        fi
      '';

in { environment.systemPackages = [ setuphome ]; }
