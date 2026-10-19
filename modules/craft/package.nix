{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  addDriverRunpath,
  alsa-lib,
  dbus,
  libGL,
  libva,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  vulkan-loader,
  wayland,
  name,
  version,
  hash,
}:

stdenv.mkDerivation {
  pname = name;
  inherit version;

  src = fetchurl {
    url = "https://github.com/storytold/${name}/releases/download/v${version}/${name}-${version}-linux-x86_64.tar.gz";
    inherit hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    alsa-lib
    (lib.getLib stdenv.cc.cc)
  ];

  # Loaded with dlopen by winit, wgpu and the file dialogs. Some apps open
  # their window through XWayland even under Wayland, hence xlib. The driver
  # link carries libnvidia-encode for FilmCraft's NVENC export.
  appendRunpaths = [
    (lib.makeLibraryPath [
      dbus
      libGL
      libva
      libx11
      libxcb
      libxcursor
      libxi
      libxkbcommon
      libxrandr
      vulkan-loader
      wayland
    ])
    "${addDriverRunpath.driverLink}/lib"
  ];

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/storytold/${name}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = name;
  };
}
