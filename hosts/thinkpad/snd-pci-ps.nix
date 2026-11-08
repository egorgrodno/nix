{
  stdenv,
  kernel,
  kernelModuleMakeFlags,
}:

# Only snd-pci-ps, rebuilt from the running kernel's source with the patch, so
# the kernel itself still comes from the binary cache. depmod prefers a module
# under updates/ over the in-tree one of the same name.
stdenv.mkDerivation {
  pname = "snd-pci-ps-patched";
  inherit (kernel) version src;

  patches = [ ./acp63-irq-powered-off.patch ];

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [
    "pic"
    "format"
  ];

  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(PWD)/sound/soc/amd/ps"
  ];
  buildFlags = [ "modules" ];

  installPhase = ''
    runHook preInstall
    install -Dm444 sound/soc/amd/ps/snd-pci-ps.ko \
      $out/lib/modules/${kernel.modDirVersion}/updates/snd-pci-ps.ko
    runHook postInstall
  '';
}
