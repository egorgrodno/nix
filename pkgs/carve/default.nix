{
  lib,
  buildGoModule,
  makeWrapper,
  git,
}:

buildGoModule {
  pname = "carve";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (f: f.hasExt "go" || f.name == "go.mod") ./.;
  };
  vendorHash = null;
  nativeBuildInputs = [ makeWrapper ];
  # The tests build repositories and commit to them.
  nativeCheckInputs = [ git ];
  postInstall = ''
    wrapProgram $out/bin/carve --prefix PATH : ${lib.makeBinPath [ git ]}
  '';
  meta.mainProgram = "carve";
}
