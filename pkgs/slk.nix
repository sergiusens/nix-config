# slk: a keyboard-driven terminal UI for Slack, no Electron required.
#
# Packaging lifted from wimpysworld/nix-config (pkgs/slk/default.nix), with
# thanks. Upstream ships a flake.nix, but it pins version "0.0.0" and builds
# from a local path, so this builds from the release tag instead.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  libX11,
  makeDesktopItem,
  makeWrapper,
  stdenv,
  symlinkJoin,
  wl-clipboard,
  xdg-utils,
}:
let
  slk-unwrapped = buildGoModule (finalAttrs: {
    pname = "slk";
    version = "0.25.0";

    src = fetchFromGitHub {
      owner = "gammons";
      repo = "slk";
      tag = "v${finalAttrs.version}";
      hash = "sha256-b42gnHzBYAcypqvdOaUVHjWyXiC36aVVGKfCVi8VFjU=";
    };

    vendorHash = "sha256-/J4gr4m9v6Y0Be8BU4wepIdl2sjoPh0pFCvJL2kIeLk=";

    subPackages = [ "cmd/slk" ];

    nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ makeWrapper ];

    # Clipboard support comes from golang.design/x/clipboard, which needs cgo and
    # Xlib. The upstream release binaries set CGO_ENABLED=0, which silently drops
    # image paste; keep cgo on instead.
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ libX11 ];

    ldflags = [
      "-s"
      "-w"
      "-X main.version=${finalAttrs.version}"
    ];

    # The clipboard library reaches Xlib through dlopen("libX11.so"), so it never
    # becomes a link-time dependency and the runpath does not cover it. Under
    # Wayland slk reads the clipboard with wl-paste, and it opens links and files
    # with xdg-open.
    postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
      wrapProgram $out/bin/slk \
        --suffix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libX11 ]} \
        --suffix PATH : ${
          lib.makeBinPath [
            wl-clipboard
            xdg-utils
          ]
        }
    '';

    meta = {
      description = "Keyboard-driven terminal user interface for Slack";
      homepage = "https://github.com/gammons/slk";
      changelog = "https://github.com/gammons/slk/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "slk";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  });

  # slk is a TUI, so the launcher entry has to open a terminal rather than
  # exec the binary directly. Matches the uwsm-wrapped launches already used
  # for terminal keybinds in home/sergiusens/hyprland.nix.
  desktopItem = makeDesktopItem {
    name = "slk";
    desktopName = "slk";
    comment = slk-unwrapped.meta.description;
    exec = "uwsm app -- ghostty -e slk";
    icon = "slack"; # no icon of its own; Papirus ships a real Slack glyph
    terminal = false; # Exec already opens its own terminal
    categories = [
      "Network"
      "Chat"
    ];
  };
in
symlinkJoin {
  name = "slk-${slk-unwrapped.version}";
  paths = [
    slk-unwrapped
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ desktopItem ];
  inherit (slk-unwrapped) meta;
}
