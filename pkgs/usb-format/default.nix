{
  writeShellApplication,
  coreutils,
  jq,
  libnotify,
  systemd,
  util-linux,
}:

writeShellApplication {
  name = "usb-format";
  runtimeInputs = [
    coreutils
    jq
    libnotify
    systemd
    util-linux
  ];
  text = builtins.readFile ./usb-format.sh;
}
