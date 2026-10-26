{ pkgs, lib, ... }:

let
  apps = lib.mapAttrs (name: src: pkgs.callPackage ./package.nix ({ inherit name; } // src)) (
    lib.importJSON ./sources.json
  );
  opens = app: types: lib.genAttrs types (_: "ai.storyteller.${app}.desktop");

  # Each app's MCP server arguments, as the craft plugin's .mcp.json gives
  # them. A server started with others has no cache, so mcp-lazy starts it at
  # once.
  roots = [
    "--automation-read-root"
    "\${CLAUDE_PROJECT_DIR}"
    "--automation-write-root"
    "\${CLAUDE_PROJECT_DIR}"
  ];
  mcpArgs = {
    cadcraft = [ ];
    deckcraft = roots;
    designcraft = roots;
    effectcraft = roots;
    figcraft = roots;
    filmcraft = [ ];
    gridcraft = [ ];
    lightcraft = [ "--compact" ];
    pdfcraft = [ "--compact" ] ++ roots;
    photocraft = roots;
    soundcraft = roots;
    vectorcraft = roots;
    wordcraft = roots;
  };
  mcp-lazy = pkgs.callPackage ../../pkgs/mcp-lazy { };
  record = name: args: ''
    ${lib.getExe mcp-lazy} -record ${lib.getExe' apps.${name} "${name}-cli"} mcp \
      ${lib.escapeShellArgs args} > $out/${name}-cli.json
  '';
  mcpCache = pkgs.runCommand "craft-mcp-cache" { } ''
    mkdir $out
    export HOME=$TMPDIR
    ${lib.concatStrings (lib.mapAttrsToList record mcpArgs)}
  '';
in
{
  home.packages = lib.attrValues apps ++ [
    (pkgs.callPackage ../../pkgs/craft-update { })
    (pkgs.runCommand "mcp-lazy" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
      makeWrapper ${lib.getExe mcp-lazy} $out/bin/mcp-lazy --add-flags "-cache ${mcpCache}"
    '')
  ];

  # The tarballs are only build inputs, which garbage collection takes; kept,
  # rebuilding the pinned versions needs no GitHub.
  home.extraDependencies = lib.mapAttrsToList (_: app: app.src) apps;

  # A viewer in modules/desktop keeps PDF, SVG, images and video; each app
  # still lists itself under "Open with" for them.
  xdg.mimeApps.defaultApplications =
    opens "wordcraft" [
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
      "application/vnd.ms-word.document.macroEnabled.12"
      "application/vnd.ms-word.template.macroEnabled.12"
      "application/msword"
      "application/msword-template"
      "application/vnd.oasis.opendocument.text"
      "application/rtf"
      "text/rtf"
    ]
    // opens "gridcraft" [
      "application/vnd.ms-excel"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.ms-excel.sheet.macroEnabled.12"
      "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
      "application/vnd.oasis.opendocument.spreadsheet"
      "text/csv"
      "text/tab-separated-values"
    ]
    // opens "deckcraft" [
      "application/x-deckcraft"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/vnd.openxmlformats-officedocument.presentationml.template"
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
    ]
    // opens "cadcraft" [
      "image/vnd.dxf"
      "image/vnd.dwg"
      "application/x-dxf"
      "application/acad"
    ]
    // opens "designcraft" [
      "application/x-designcraft"
      "application/vnd.adobe.indesign-idml-package"
    ]
    // opens "figcraft" [
      "application/x-figcraft"
      "x-scheme-handler/figcraft"
    ]
    // opens "filmcraft" [ "application/x-filmcraft" ]
    // opens "lightcraft" [
      "image/x-adobe-dng"
      "image/x-sony-arw"
      "image/x-canon-cr2"
      "image/x-canon-cr3"
      "image/x-nikon-nef"
      "image/x-fuji-raf"
      "image/x-olympus-orf"
      "image/x-panasonic-rw2"
      "image/x-panasonic-rw"
      "image/x-pentax-pef"
    ]
    // opens "photocraft" [
      "application/x-photocraft"
      "image/vnd.adobe.photoshop"
      "image/x-psd"
      "image/x-psb"
      "image/openraster"
      "image/x-paintnet"
    ]
    // opens "soundcraft" [ "application/x-soundcraft-session" ];

  # GridCraft imports .xls, but its desktop entry omits the type until
  # storytold/gridcraft#1436 lands.
  xdg.mimeApps.associations.added = opens "gridcraft" [ "application/vnd.ms-excel" ];
}
