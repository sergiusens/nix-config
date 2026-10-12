# GPU-accelerated RAW editor, Rust/egui, not packaged in nixpkgs. Upstream
# only ships binaries (AppImage/apk/zip/exe), no source build is documented,
# so wrapping the x86_64 AppImage is the straightforward path.
{
  lib,
  appimageTools,
  fetchurl,
}:
let
  pname = "calibraw";
  version = "1.2.1";

  src = fetchurl {
    url = "https://github.com/Duecki1/CalibRaw/releases/download/v${version}/CalibRaw-x86_64.AppImage";
    hash = "sha256-RkxWXjh3Vzah4DkZ5tc9EGUwLdqZOARzSrtG9wdZsWU=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/de.duecki.calibraw.desktop \
      $out/share/applications/de.duecki.calibraw.desktop
    install -m 444 -D ${appimageContents}/de.duecki.calibraw.png \
      $out/share/icons/hicolor/256x256/apps/de.duecki.calibraw.png
    substituteInPlace $out/share/applications/de.duecki.calibraw.desktop \
      --replace-fail 'Exec=calibraw' 'Exec=${pname}'
  '';

  meta = {
    description = "GPU-first, non-destructive RAW image editor";
    homepage = "https://github.com/Duecki1/CalibRaw";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "calibraw";
  };
}
