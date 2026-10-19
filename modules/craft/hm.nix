{ pkgs, lib, ... }:

let
  apps = lib.mapAttrsToList (name: src: pkgs.callPackage ./package.nix ({ inherit name; } // src)) (
    lib.importJSON ./sources.json
  );
  opens = app: types: lib.genAttrs types (_: "ai.storyteller.${app}.desktop");
in
{
  home.packages = apps ++ [ (pkgs.callPackage ../../pkgs/craft-update { }) ];

  # The tarballs are only build inputs, which garbage collection takes; kept,
  # rebuilding the pinned versions needs no GitHub.
  home.extraDependencies = map (app: app.src) apps;

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
