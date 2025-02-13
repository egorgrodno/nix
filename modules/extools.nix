{ pkgs, username, ... }:

let
  binPath = "$HOME/.config/bin";
in {
  home-manager.users.${username} = {
    programs.zsh.initExtra = ''
      export PATH="$PATH:${binPath}"
    '';

    home.packages = [
      (pkgs.writeShellScriptBin "exlist" ''
        ls -lh ${binPath}
      '')

      (pkgs.writeShellScriptBin "exinit" ''
        set -e

        # Check if a file path is provided
        if [ -z "$1" ]; then
          echo "Usage: $(basename $0) path_to_file"
          exit 1
        fi

        # Get the full path to the file
        FILE_PATH="$1"

        echo -e "#!/usr/bin/env bash\n\n" > $FILE_PATH
        chmod +x $FILE_PATH

        echo "Script initiated: $FILE_PATH"
      '')

      (pkgs.writeShellScriptBin "exinit" ''
        set -e

        # Check if a file path is provided
        if [ -z "$1" ]; then
          echo "Usage: $(basename $0) path_to_file"
          exit 1
        fi

        # Get the full path to the file
        FILE_PATH="$1"

        echo -e "#!/usr/bin/env bash\n\n" > $FILE_PATH
        chmod +x $FILE_PATH

        echo "Script initiated: $FILE_PATH"
      '')

      (pkgs.writeShellScriptBin "exlink" ''
        # Check if a file path is provided
        if [ -z "$1" ]; then
          echo "Usage: $(basename $0) path_to_file"
          exit 1
        fi

        # Get the full path to the file
        FILE_PATH=$(realpath --relative-to="${binPath}" "$1")

        # Check if the file exists
        if [ ! -f "$FILE_PATH" ]; then
          echo "File not found: $FILE_PATH"
          exit 2
        fi

        FILE_NAME=$(basename "$FILE_PATH")
        SYMLINK_PATH="${binPath}/$FILE_NAME"

        mkdir -p "${binPath}"

        # Create the symlink
        ln -s "$FILE_PATH" "$SYMLINK_PATH"

        echo "Executable added to PATH: $(basename $FILE_PATH)"
      '')

      (pkgs.writeShellScriptBin "exunlink" ''
        set -e

        # Check if a file path is provided
        if [ -z "$1" ]; then
          echo "Usage: `basename $0` path_to_file"
          exit 1
        fi

        FILE_NAME=$(basename "$1")

        rm "${binPath}/$FILE_NAME"

        echo "Executable removed from PATH: $(basename $FILE_PATH)"
      '')
    ];
  };
}
