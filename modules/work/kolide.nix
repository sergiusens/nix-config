# Kolide launcher (osquery agent) for kynes.
#
# ############################# NOT YET WORKING #############################
# Disabled by default and UNTESTED. Considerably more tractable than the Falcon
# sensor: the launcher is a mostly-static Go binary and osqueryd needs only
# patchelf, both fetched from dl.kolide.co without authentication. bluefin-xp
# pins launcher 1.31.7 and osqueryd 5.20.0.
#
# Remaining work:
#   - fill in the two sha256 hashes (lib.fakeHash below will fail loudly and
#     print the real value; paste it back in)
#   - the launcher self-updates by default ("autoupdate" in its flags), which
#     fights the whole point of a declarative system. Consider dropping that
#     flag and bumping the version here instead.
#   - the enrollment secret is a secret: sops-nix, never the nix store. Note
#     that bluefin-xp's ujust recipe wrote it to /etc/kolide-k2/secret at 0600.
# ###########################################################################
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fleet.kolide;

  launcherVersion = "1.31.7";
  osquerydVersion = "5.20.0";

  launcher = pkgs.fetchurl {
    url = "https://dl.kolide.co/kolide/launcher/linux/amd64/launcher-${launcherVersion}.tar.gz";
    hash = lib.fakeHash;
  };

  osqueryd = pkgs.fetchurl {
    url = "https://dl.kolide.co/kolide/osqueryd/linux/amd64/osqueryd-${osquerydVersion}.tar.gz";
    hash = lib.fakeHash;
  };
in
{
  options.fleet.kolide = {
    enable = lib.mkEnableOption "Kolide launcher (untested on NixOS)";

    secretFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the enrollment secret, e.g. config.sops.secrets.kolide.path.";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = [
      "fleet.kolide is enabled but this module is untested; the fetchurl hashes are placeholders."
    ];

    systemd.services."launcher.kolide-k2" = {
      description = "The Kolide Launcher";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 3;
        StateDirectory = "kolide-k2";
      };

      # Placeholder: unpack the two tarballs into a derivation and point
      # ExecStart at it with a generated launcher.flags, mirroring the config
      # bluefin-xp wrote to /etc/kolide-k2/launcher.flags.
      script = ''
        echo "kolide launcher not yet packaged; see ${toString ./kolide.nix}" >&2
        echo "sources: ${launcher} ${osqueryd}" >&2
        exit 1
      '';
    };
  };
}
