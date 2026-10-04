# thufir — the home server. Was `orthanc` on ghcr.io/ublue-os/ucore:stable.
#
# ############################ HARDWARE UNKNOWN #############################
# Generate hosts/thufir/hardware-configuration.nix on the machine itself before
# installing. The one clue carried over from orthanc.bu is that the LAN comes up
# on enp0s20f0u3 — a USB-attached NIC — so confirm the interface name too.
# ###########################################################################
#
# ############################ DATA LIVES HERE ##############################
# Migrating this host is not like the laptops. Some state is on the NAS and
# survives untouched; some is local and must be moved deliberately:
#
#   LOCAL — must be migrated          ON shadout (NFS) — survives
#   /var/lib/immich/db  (Postgres)    /var/mnt/nas/immich/upload   (the photos)
#   /var/lib/adguardhome/{work,conf}  /var/mnt/nas/immich/ml-cache
#   freshrss-data, freshrss-extensions   /var/mnt/nas/luanti        (the world)
#     (named podman volumes)          /var/mnt/nas/gthumb-sergiusens
#   /var/lib/tailscale
#
# The Immich Postgres volume is the one that matters. Back it up with
# `pg_dump` from the running orthanc BEFORE touching anything, not by copying
# the data directory, which is not portable across Postgres versions.
# ###########################################################################
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Pinned exactly as orthanc had them. Immich in particular is a matched set:
  # the server, ML and database images move together, and the database image is
  # not stock Postgres — it carries the vector extensions Immich requires.
  immichVersion = "release";
  immichPgImage = "ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0";

  lanAddress = "192.168.0.100";
  nasAddress = "192.168.0.101";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Deliberately NO desktop profile, no hyprland, no dank, no desktop-apps.
  # This host is headless.

  # -------------------------------------------------------------- networking --
  # A static address, because this host is the LAN's DNS resolver: it cannot
  # depend on DHCP from a router that is in turn asking it for names.
  # systemd-networkd rather than NetworkManager — nothing roams here.
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    networks."10-lan" = {
      # Carried over from orthanc.bu. VERIFY on the real hardware: this is a
      # USB NIC and the name is not stable across chassis changes.
      matchConfig.Name = "enp0s20f0u3";
      address = [ "${lanAddress}/24" ];
      gateway = [ "192.168.0.1" ];
      dns = [ "192.168.0.1" ];
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # AdGuard owns port 53 on this machine. resolved's stub listener would fight
  # it for 127.0.0.53, which is exactly the collision the bluefin-xp comments
  # warned about.
  services.resolved.enable = lib.mkForce false;

  # --------------------------------------------------------------- NAS mount --
  # Bulk storage lives on shadout and is mounted on demand rather than at boot,
  # so a NAS that is down or slow cannot hold up the boot.
  systemd.mounts = [
    {
      what = "${nasAddress}:/orthanc";
      where = "/var/mnt/nas";
      type = "nfs";
      options = "_netdev,nfsvers=4,soft,timeo=100,retrans=3";
      description = "shadout bulk storage";
    }
  ];

  systemd.automounts = [
    {
      where = "/var/mnt/nas";
      wantedBy = [ "multi-user.target" ];
      description = "Automount shadout";
    }
  ];

  # An NFS mount can hang hard enough that every access blocks forever and the
  # containers wedge with it. This detects that and detaches, letting the
  # automount re-establish on the next access.
  #
  # ####################### DO NOT USE `mountpoint` HERE #######################
  # orthanc's version opened with:
  #
  #     if ! timeout 5 mountpoint -q /var/mnt/nas; then exit 0; fi
  #
  # which is backwards precisely when it matters. On a hung mount `mountpoint`
  # BLOCKS, `timeout` kills it with exit 124, the `!` turns that into true, and
  # the script concludes "not mounted, nothing to do" and exits 0. Measured on
  # orthanc 2026-10-03: the mount was hung, every watchdog run exited
  # "successfully" after exactly 5 seconds, and it had been doing that for
  # weeks while luanti accumulated 2168 failed starts.
  #
  # Reading /proc/mounts cannot block, so the liveness test is the only part
  # allowed to time out.
  # ###########################################################################
  #
  # `umount -l` returns immediately even on an unresponsive mount, and stopping
  # the mount unit with --no-block avoids deadlocking in systemd's own job
  # transaction.
  systemd.services.nas-watchdog = {
    description = "NAS mount watchdog — remount if hung";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    path = with pkgs; [
      util-linux
      coreutils
      systemd
      gnugrep
    ];
    script = ''
      # Never blocks, unlike mountpoint(1).
      if ! grep -q " /var/mnt/nas nfs" /proc/mounts; then
        exit 0
      fi
      if timeout 10 ls /var/mnt/nas > /dev/null 2>&1; then
        exit 0
      fi
      echo "NAS mount at /var/mnt/nas is hung, detaching so the automount can retry"
      umount -l /var/mnt/nas || true
      systemctl --no-block stop var-mnt-nas.mount
    '';
  };

  systemd.timers.nas-watchdog = {
    description = "Run NAS mount watchdog every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };

  # ------------------------------------------------------------- state dirs --
  # Ported from orthanc.tmpfiles. The 999:999 on the database directory is the
  # postgres uid inside Immich's image and must match, or it will not start.
  systemd.tmpfiles.rules = [
    "d /var/mnt/nas 0777 root root - -"
    "d /var/lib/immich 0755 root root - -"
    "d /var/lib/immich/db 0750 999 999 - -"
    "d /var/lib/adguardhome 0755 root root - -"
    "d /var/lib/adguardhome/work 0755 root root - -"
    "d /var/lib/adguardhome/conf 0755 root root - -"
  ];

  # ------------------------------------------------------------- containers --
  # Kept as containers rather than rewritten onto services.immich and friends.
  # That is a deliberate, conservative choice: the Postgres image is pinned with
  # specific vector-extension versions, and moving to the NixOS module would
  # mean a dump-and-restore across Postgres versions with the family photo
  # archive on the line. Worth doing later, on purpose, not as a side effect of
  # changing operating system.
  #
  # The one structural change from orthanc: Immich used a podman *pod* so its
  # containers shared localhost. nixpkgs' oci-containers has no pod support, so
  # this uses a network and explicit hostnames — which is what upstream
  # Immich's own compose file does anyway.
  virtualisation.oci-containers = {
    backend = "podman";

    containers = {
      immich-db = {
        image = immichPgImage;
        environmentFiles = [ config.sops.secrets.immich-env.path ];
        volumes = [ "/var/lib/immich/db:/var/lib/postgresql/data" ];
        networks = [ "immich" ];
        extraOptions = [ "--user=999:999" ];
      };

      immich-redis = {
        image = "docker.io/redis:6.2-alpine";
        networks = [ "immich" ];
      };

      immich-ml = {
        image = "ghcr.io/immich-app/immich-machine-learning:${immichVersion}";
        volumes = [ "/var/mnt/nas/immich/ml-cache:/cache" ];
        networks = [ "immich" ];
        dependsOn = [ "immich-db" ];
      };

      immich-server = {
        image = "ghcr.io/immich-app/immich-server:${immichVersion}";
        environmentFiles = [ config.sops.secrets.immich-env.path ];
        volumes = [
          "/var/mnt/nas/immich/upload:/usr/src/app/upload"
          "/var/mnt/nas/gthumb-sergiusens:/mnt/gthumb-sergiusens"
        ];
        ports = [ "2283:2283" ];
        networks = [ "immich" ];
        dependsOn = [
          "immich-db"
          "immich-redis"
        ];
      };

      freshrss = {
        image = "docker.io/freshrss/freshrss:latest";
        volumes = [
          "freshrss-data:/var/www/FreshRSS/data"
          "freshrss-extensions:/var/www/FreshRSS/extensions"
        ];
        ports = [ "8080:80" ];
        environment = {
          TZ = "UTC";
          CRON_MIN = "1,31";
        };
      };

      adguardhome = {
        image = "docker.io/adguard/adguardhome:latest";
        volumes = [
          "/var/lib/adguardhome/work:/opt/adguardhome/work"
          "/var/lib/adguardhome/conf:/opt/adguardhome/conf"
        ];
        # DNS is bound to explicit addresses, never a wildcard :53 — a wildcard
        # would also claim 127.0.0.53 and hijack the host's own resolution.
        #
        # NOTE: the tailnet address was hardcoded on orthanc too, and it is
        # fragile: if tailscaled has not assigned it yet at container start,
        # the bind fails. Worth revisiting with a tailscale-up ordering
        # dependency.
        ports = [
          "${lanAddress}:53:53/udp"
          "${lanAddress}:53:53/tcp"
          "3000:80/tcp"
        ];
        environment.TZ = "UTC";
      };

      luanti = {
        image = "ghcr.io/luanti-org/luanti:latest";
        volumes = [ "/var/mnt/nas/luanti:/var/lib/minetest/.minetest" ];
        ports = [
          "30000:30000/udp"
          "30000:30000/tcp"
        ];
        extraOptions = [ "--user=1000" ];
        cmd = [
          "--gameid"
          "mineclonia"
          "--worldname"
          "Minecraft"
          "--port"
          "30000"
        ];
      };
    };
  };

  # The network the Immich containers share, replacing the pod.
  systemd.services.podman-network-immich = {
    path = [ pkgs.podman ];
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = "podman network inspect immich >/dev/null 2>&1 || podman network create immich";
  };

  # ----------------------------------------------------------------- secrets --
  # Immich's database credentials. On orthanc these sat in /etc/immich/env,
  # created by hand on the machine and never in the repository — so its exact
  # contents are not known here. Retrieve it from the running server before
  # migrating:  sudo cat /etc/immich/env
  sops.secrets.immich-env = {
    sopsFile = ../../secrets/thufir.yaml;
    format = "binary";
  };

  # ---------------------------------------------------------------- firewall --
  networking.firewall = {
    allowedTCPPorts = [
      53 # AdGuard DNS
      2283 # Immich
      3000 # AdGuard web UI
      8080 # FreshRSS
      30000 # Luanti
    ];
    allowedUDPPorts = [
      53
      30000
    ];
  };

  # system.stateVersion comes from modules/common; defining it twice conflicts.
}
