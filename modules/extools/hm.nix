{ pkgs, ... }:

let
  binPath = "$HOME/.config/bin";
in {
  programs.zsh.initContent = ''
    export PATH="$PATH:${binPath}"
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "exlist" ''
      ls -lh ${binPath}
    '')

    (pkgs.writeShellScriptBin "exinit" ''
      set -e

      if [ -z "$1" ]; then
        echo "Usage: $(basename $0) path_to_file"
        exit 1
      fi

      FILE_PATH="$1"

      echo -e "#!/usr/bin/env bash\n\n" > $FILE_PATH
      chmod +x $FILE_PATH

      echo "Script initiated: $FILE_PATH"
    '')

    (pkgs.writeShellScriptBin "exlink" ''
      if [ -z "$1" ]; then
        echo "Usage: $(basename $0) path_to_file"
        exit 1
      fi

      # Relative to binPath, so the link survives the target tree being moved.
      FILE_PATH=$(realpath --relative-to="${binPath}" "$1")

      if [ ! -f "$FILE_PATH" ]; then
        echo "File not found: $FILE_PATH"
        exit 2
      fi

      FILE_NAME=$(basename "$FILE_PATH")
      SYMLINK_PATH="${binPath}/$FILE_NAME"

      mkdir -p "${binPath}"

      ln -s "$FILE_PATH" "$SYMLINK_PATH"

      echo "Executable added to PATH: $(basename $FILE_PATH)"
    '')

    (pkgs.writeShellScriptBin "exunlink" ''
      set -e

      if [ -z "$1" ]; then
        echo "Usage: `basename $0` path_to_file"
        exit 1
      fi

      FILE_NAME=$(basename "$1")

      rm "${binPath}/$FILE_NAME"

      echo "Executable removed from PATH: $(basename $FILE_PATH)"
    '')
  ];
}
