{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "mcp-lazy";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (f: f.hasExt "go" || f.name == "go.mod") ./.;
  };
  vendorHash = null;
  meta.mainProgram = "mcp-lazy";
}
