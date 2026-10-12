# Desktop photo manager / RAW editor (Avalonia/.NET), not packaged in
# nixpkgs. Upstream publishes an x86_64 AppImage alongside the .deb/.rpm/zip
# builds, so wrapping that is the straightforward path.
{
  lib,
  appimageTools,
  fetchurl,
}:
let
  pname = "ferrumpix";
  version = "0.9.64-2";

  src = fetchurl {
    url = "https://github.com/Bitpainter75/FerrumPix/releases/download/latest/FerrumPix-${version}-x86_64.AppImage";
    hash = "sha256-70iiJP4KIwNuH5ZTbqRUiZ7GeTJFzZih0Jd9J+Wtt8A=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/io.github.Bitpainter75.FerrumPix.desktop \
      $out/share/applications/io.github.Bitpainter75.FerrumPix.desktop
    install -m 444 -D ${appimageContents}/io.github.Bitpainter75.FerrumPix.png \
      $out/share/icons/hicolor/256x256/apps/io.github.Bitpainter75.FerrumPix.png
    substituteInPlace $out/share/applications/io.github.Bitpainter75.FerrumPix.desktop \
      --replace-fail 'Exec=ferrumpix %F' 'Exec=${pname} %F'
  '';

  meta = {
    description = "Desktop photo manager, RAW editor, viewer and gallery with Immich/Nextcloud integration";
    homepage = "https://github.com/Bitpainter75/FerrumPix";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ferrumpix";
  };
}
