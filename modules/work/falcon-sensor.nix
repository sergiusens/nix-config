# CrowdStrike Falcon sensor for kynes.
#
# ############################# NOT YET WORKING #############################
# Disabled by default and UNTESTED. This is a documented starting point, not a
# solved problem — do not assume it runs. Packaging a vendor EDR agent for NixOS
# is the single hardest part of moving kynes off bootc, and it is why the split
# recommendation kept the work laptop on Bluefin.
#
# What makes it awkward:
#   - falcon-sensor ships only as an RPM of prebuilt ELF binaries, so it needs
#     autoPatchelfHook against nixpkgs' libraries.
#   - It is not redistributable. The RPM must come from your CrowdStrike tenant;
#     bluefin-xp pulled it from a private GitHub release and checked the sha256
#     (falcon-sensor-7.33.0-18606.el10.x86_64.rpm).
#   - It expects to live at a fixed FHS path, /opt/CrowdStrike, and to WRITE
#     there. bluefin-xp solved the read-only-/opt problem by storing binaries in
#     /usr/lib/CrowdStrike and symlinking /opt/CrowdStrike -> /var/opt/CrowdStrike.
#     On NixOS the equivalent is a systemd service with BindPaths, or an FHS
#     userenv via pkgs.buildFHSEnv.
#   - The sensor's bpf backend wants kernel headers/BTF matching the running
#     kernel. boot.kernelPackages = linuxPackages_latest may outrun what
#     CrowdStrike supports; pin the kernel on this host if so.
#   - The CID is a secret and must come from sops-nix, never the nix store.
#
# Before sinking time into this, check whether your employer accepts the Kolide
# agent alone, or whether a NixOS machine is permitted on the network at all.
# ###########################################################################
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fleet.falcon;
in
{
  options.fleet.falcon = {
    enable = lib.mkEnableOption "CrowdStrike Falcon sensor (untested on NixOS)";

    rpm = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the falcon-sensor RPM from your CrowdStrike tenant. Use
        pkgs.requireFile so the hash is recorded without the RPM entering git.
      '';
    };

    cidFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file holding the Customer ID, e.g. a sops secret.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Sketch only — expect to iterate on buildInputs until autoPatchelf is happy.
    environment.systemPackages = [
      (pkgs.stdenv.mkDerivation {
        pname = "falcon-sensor";
        version = "unknown";
        src = cfg.rpm;

        nativeBuildInputs = with pkgs; [
          rpm
          cpio
          autoPatchelfHook
        ];
        buildInputs = with pkgs; [
          openssl
          zlib
          libnl
          elfutils
          libpcap
        ];

        unpackPhase = "rpm2cpio $src | cpio -idmv";
        installPhase = ''
          mkdir -p $out
          cp -r opt/CrowdStrike $out/
        '';

        meta.license = lib.licenses.unfree;
      })
    ];

    warnings = [
      "fleet.falcon is enabled but this module is untested; verify the sensor actually reports in before trusting kynes on a managed network."
    ];
  };
}
