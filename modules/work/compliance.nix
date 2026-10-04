# Policy and compliance agents for the work laptop.
#
# Two proprietary endpoint agents, neither of which can be packaged
# declaratively:
#   - CrowdStrike Falcon  — EDR. Binaries bootstrapped imperatively to
#                           /opt/CrowdStrike by falcon-sensor-install, then
#                           patchelf'd onto the Nix glibc interpreter.
#   - Kolide launcher     — device trust. Packaged properly upstream by Kolide
#                           themselves at github:kolide/nix-agent.
#
# The Falcon module and its scripts are vendored from a colleague's config under
# the Blue Oak Model License — see ATTRIBUTION.md in this directory. This file is
# the fleet-specific glue.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.work.compliance;
  username = "sergiusens";

  # Automates bootstrap and update of the Falcon sensor: resolves the release
  # from a private repo, downloads the RPM via gh, extracts it, copies binaries
  # into place and patches every ELF with the Nix glibc interpreter. Stages the
  # update instead when a sensor is already running, because 7.38+ tamper
  # protection write-protects /opt/CrowdStrike even against root.
  falconSensorInstall = pkgs.writeShellApplication {
    name = "falcon-sensor-install";
    runtimeInputs = with pkgs; [
      coreutils
      cpio
      gh
      gnugrep
      jq
      patchelf
      procps
      rpm
      systemd
    ];
    text = builtins.readFile ./falcon-sensor-install.sh;
  };

  # Health check: service state, CID, agent ID, RFM status, backend, log owner.
  falconSensorCheck = pkgs.writeShellApplication {
    name = "falcon-sensor-check";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      procps
      systemd
    ];
    text = builtins.readFile ./falcon-sensor-check.sh;
  };
in
{
  imports = [ ./falcon-sensor.nix ];

  options.work.compliance.enable = lib.mkEnableOption ''
    work endpoint compliance agents (CrowdStrike Falcon and Kolide).

    Requires secrets/compliance.yaml to be a real sops-encrypted file containing
    kolide, falcon-cid and falcon-repo. Leaving this off is the correct state
    until those exist
  '';

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      falconSensorInstall
      falconSensorCheck
    ];

    # ------------------------------------------------------------- CrowdStrike --
    # The sensor does not start until falcon-sensor-install has placed binaries
    # at /opt/CrowdStrike; the unit carries a ConditionPathExists for falcond.
    # The kernel-module backend does not work on NixOS, so the module forces
    # --backend=bpf in ExecStartPre.
    services.falcon-sensor = {
      enable = true;
      cidFile = config.sops.secrets.falcon-cid.path;
      traceLevel = "err";
      # Suppresses repeated "Could not retrieve DisableProxy value: c0000225"
      # noise on hosts with no proxy. Falcon connects directly regardless.
      disableAutoProxyDetection = true;
    };

    # ------------------------------------------------------------------ Kolide --
    # Package and base service come from Kolide's own flake, wired in
    # flake.nix as inputs.kolide-launcher.nixosModules.kolide-launcher.
    services.kolide-launcher.enable = true;

    systemd.services.kolide-launcher = {
      path = [
        pkgs.xdg-utils
        pkgs.glib
      ];
      serviceConfig = {
        # The launcher spawns a per-user "launcher desktop" process with a fresh
        # environment, copying only PATH from this unit (desktopCommand in
        # ee/desktop/runner/runner.go). Anything the tray AppIndicator needs
        # must therefore resolve through PATH — including the per-user
        # home-manager profile, so browsers named in .desktop Exec entries are
        # found when a menu item is clicked.
        Environment = lib.mkForce (
          "PATH=/run/wrappers/bin:/bin:/sbin"
          + ":/nix/var/nix/profiles/default/bin"
          + ":/run/current-system/sw/bin"
          + ":/etc/profiles/per-user/${username}/bin"
          + ":/home/${username}/.nix-profile/bin"
          + ":${config.systemd.services.kolide-launcher.environment.PATH}"
        );

        # The 90 s default is occasionally too short for osquery to flush its
        # event store on a long-running workstation; the result is a SIGKILL of
        # launcher and osqueryd with writes half-flushed. Observed after roughly
        # nine hours of uptime. mkDefault so a host can raise it further.
        TimeoutStopSec = lib.mkDefault 180;
      };
    };

    # ----------------------------------------------------------------- secrets --
    # Obtain the Kolide enrollment secret from the Slack bot or web enrollment
    # (it can also be extracted from the vendor .deb/.rpm). falcon-repo is the
    # owner/name of the private repository holding the sensor RPM releases;
    # falcon-sensor-install reads it from /run/secrets/falcon-repo.
    sops.secrets = {
      kolide = {
        mode = "0600";
        path = "/etc/kolide-k2/secret";
        sopsFile = ../../secrets/compliance.yaml;
      };
      falcon-cid = {
        mode = "0600";
        sopsFile = ../../secrets/compliance.yaml;
      };
      falcon-repo = {
        mode = "0600";
        sopsFile = ../../secrets/compliance.yaml;
      };
    };
  };
}
