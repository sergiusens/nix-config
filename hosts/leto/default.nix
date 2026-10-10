# leto — Dell XPS 13 Plus 9320. Photo workstation.
#
# 13th Gen Intel Core i7-1360P (Raptor Lake-P), Iris Xe graphics, 30 GiB RAM,
# 1 TB NVMe, Intel AX211 wifi/bluetooth. UEFI, LUKS-on-btrfs.
#
# Hardware quirks come from nixos-hardware's dell-xps-13-9320 module, wired up
# in flake.nix rather than imported here.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/dank.nix
    ../../modules/hardware/intel-graphics.nix
    ../../modules/hardware/ipu6-camera.nix
    ../../modules/hardware/printing.nix
    ../../modules/hardware/secure-boot.nix
    ../../modules/hardware/dock-sleep-guard.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/desktop.nix # audio, fonts, flatpak, keyring
    ../../modules/profiles/desktop-apps.nix
  ];

  # ------------------------------------------------------------------- memory --
  # Photo applications were dying under memory pressure on this machine. The
  # cause was not a shortage of RAM so much as the absence of anywhere to spill:
  # 16 GiB of zram (which lives inside the same 30 GiB) and vm.swappiness=10.
  #
  # The fix is in three parts:
  #   1. a real 64 GiB NVMe swapfile          -> ./disko.nix
  #   2. smaller zram + swappiness 100        -> modules/common
  #   3. keeping systemd-oomd off user apps   -> below
  #
  # systemd-oomd kills processes on *memory pressure*, before true exhaustion.
  # That is sensible for a server and hostile to a photo editor that legitimately
  # wants 25 GiB and will page. Bluefin enables it by default, and it is the most
  # likely explanation for apps vanishing without a kernel OOM message in the
  # journal. Left managing system services, told to leave user slices alone.
  #
  # Tradeoff: a genuine runaway in your session can now drive the machine into
  # heavy swapping rather than being killed early. With 64 GiB of NVMe swap that
  # means a slow, recoverable crawl instead of a lost application.
  systemd.oomd.enableUserSlices = false;

  # -------------------------------------------------------------------- sleep --
  # This machine supports ONLY s2idle. Confirmed on the running system:
  #   /sys/power/mem_sleep -> [s2idle]
  # Dell exposes no S3/deep state on the XPS 13 Plus, so suspend is Modern
  # Standby. It works (suspend entry/exit is clean in the journal, devices
  # suspend in ~1.3 s) but s2idle keeps RAM powered and drains noticeably more
  # than S3 would over a closed-lid weekend.
  #
  # Tried suspend-then-hibernate as a mitigation (suspend, then write out to
  # disk and power off after a 90 min delay) and reverted it: on 2026-10-07,
  # the 90 min alarm fired on schedule and started hibernating, but the
  # machine then sat frozen for close to four hours before the hibernation
  # image actually finished writing, and never powered off cleanly
  # afterwards -- it took a hard power-cycle to recover. Whatever device
  # fails to resume cleanly on this machine (see dock-sleep-guard.nix for the
  # other instance of this class of bug) can apparently hang the brief
  # "should I hibernate yet" wake-check just as easily as a real resume, and
  # a multi-hour unresponsive hang is a worse failure than the battery drain
  # it was meant to fix. Back to plain suspend until that root cause is
  # actually understood.
  services.logind.settings.Login.HandleLidSwitch = lib.mkForce "suspend";

  # In at least two incidents (2026-10-06 overnight, 2026-10-10), the long
  # sleep's own resume logged clean -- the hang happened on a SECOND suspend
  # requested 15-30 s after waking, before things like NetworkManager/Wi-Fi
  # had finished reconnecting. Blacklisting intel_ishtp (above the hardware
  # section) did not stop this from recurring, so it is not an ISH/LTR
  # problem specifically. This holds a blocking sleep inhibitor for the
  # first minute after every resume, so nothing -- lid, power key, power
  # menu -- can trigger a second suspend before things have settled. Cheap
  # to test, cheap to revert if it does not help.
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemd-inhibit --what=sleep --mode=block \
      --who="post-resume-cooldown" \
      --why="give the first minute after resume to settle before any re-suspend" \
      ${pkgs.coreutils}/bin/sleep 60 &
  '';

  # ------------------------------------------------------------------ hardware --
  # Verify against `nixos-generate-config --show-hardware-config` on the real
  # machine before the first install; these are the expected modules for this
  # platform, not a generated file.
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
    # Intel VMD: the NVMe controller sits behind it on this chassis when
    # firmware storage mode is set to "Intel VMD" / "RAID" rather than AHCI.
    # Without this module the boot log shows
    # "ahci 0000:00:0e.0: probe with driver ahci failed with error -12".
    # Harmless to keep loaded even if the firmware is set to AHCI instead.
    "vmd"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  hardware.enableRedistributableFirmware = true;

  # Intel Sensor Hub (lid angle, accelerometer, ambient light). Its Linux
  # driver (intel_ishtp) never released a 10.5 ms LTR (Latency Tolerance
  # Reporting -- a device telling the platform "do not sleep deeper than
  # this") even while fully idle, confirmed with
  # `sudo cat /sys/kernel/debug/pmc_core/ltr_show`. That alone is enough to
  # block the platform from ever reaching real S0ix: `slp_s0_residency_usec`
  # stayed at 0 across every suspend observed, successful or not, including
  # a clean 2h10m one. Blacklisting trades the ambient-light auto-brightness
  # sensor for the platform actually reaching deep sleep -- worth testing
  # given auto-brightness was unwanted anyway.
  boot.blacklistedKernelModules = [
    "intel_ishtp_hid"
    "intel_ish_ipc"
    "intel_ishtp"
  ];

  # Thunderbolt security/link daemon. Fedora (Bluefin) and Ubuntu both enable
  # this by default as part of their desktop stack; NixOS does not, and it is
  # the one concrete gap found so far explaining why the dock's USB hub
  # (modules/hardware/dock-sleep-guard.nix) survived suspend/resume under
  # those distros but not here: bolt is what GNOME-derived stacks use to
  # authorize and re-link Thunderbolt/USB4 devices, including the tunnelled
  # USB passthrough docks like this one present outside their native PCIe
  # tunnel. Does not replace dock-sleep-guard -- that still blocks suspend
  # outright while docked, since this alone was not verified to fix the
  # resume failure, only to close a known difference from working systems.
  services.hardware.bolt.enable = true;

  # ------------------------------------------------------------------ packages --
  # Only what is specific to leto. Everything shared lives in
  # modules/profiles/desktop-apps.nix.
  environment.systemPackages = with pkgs; [
    # --- photo workflow ---------------------------------------------------
    # These are one pipeline: ingest from the card, organise and cull, then
    # develop. gthumb is the fork in ../gthumb ("Reflect"), packaged
    # separately — see the gthumb section of README.md.
    rapid-photo-downloader # card ingest; came from a COPR on bluefin-xp
    ansel # darktable fork; the Reflect fork reads its database
    rapidraw # second raw developer; Reflect records rapidraw_export provenance
    siril # astrophotography: registration, stacking, processing
    exiftool
    imagemagick

    # --- recovery / secure boot ----------------------------------------------
    # Provides `chattr`, needed to clear the immutable flag on the efivarfs
    # entries before `sbctl enroll-keys`. The minimal installer image has it;
    # the installed system does not unless listed here.
    e2fsprogs

    # --- video --------------------------------------------------------------
    shotcut

    # --- games --------------------------------------------------------------
    luanti # this host only; also self-hosted on thufir
  ];

  # ------------------------------------------------------------- backup share --
  # The old Déjà Dup backup repository, over CIFS rather than the gvfs smb://
  # mount Déjà Dup itself uses. gvfs's SMB backend is a FUSE translation that
  # does not implement chmod, which makes restic's own lock handling fail
  # when driven from the command line against the gvfs path. A real kernel
  # cifs mount does not have that gap.
  #
  # Credentials come from secrets/leto.yaml via sops-nix: cifs_username and
  # cifs_password, combined into one credentials= file at activation time
  # since mount.cifs wants both in a single file.
  sops.secrets = {
    cifs_username.sopsFile = ../../secrets/leto.yaml;
    cifs_password.sopsFile = ../../secrets/leto.yaml;
  };

  sops.templates."cuivienen-cifs-credentials" = {
    content = ''
      username=${config.sops.placeholder.cifs_username}
      password=${config.sops.placeholder.cifs_password}
    '';
    owner = "root";
    mode = "0400";
  };

  fileSystems."/mnt/cuivienen" = {
    device = "//192.168.0.101/cuivienen";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."cuivienen-cifs-credentials".path}"
      "uid=${toString config.users.users.sergiusens.uid}"
      "gid=100" # "users", sergiusens' default primary group
      "vers=3.0"
      "_netdev"
      "nofail" # never block boot on a NAS that might be off
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=10s"
    ];
  };

  # NOTE: nextcloud-client was removed. It was carried over from bluefin-xp's
  # flatpak preinstall list rather than requested, like darktable and gimp
  # before it. It also starts itself unprompted: the package ships a D-Bus
  # activatable service (com.nextcloudgmbh.Nextcloud -> `nextcloud
  # --background`) together with Nautilus/Caja/Dolphin extensions whose job is
  # to talk to it, so merely having it installed is enough for something to
  # activate it.
  #
  # To bring it back without the surprise, add the package and mask the
  # activation by shadowing the .service file in share/dbus-1/services, or just
  # launch it deliberately from the launcher.

  # ---------------------------------------------------------------- VM variant --
  # Applies ONLY to `nix build .#nixosConfigurations.leto.config.system.build.vm`,
  # never to the installed system — virtualisation.vmVariant is a separate
  # configuration layered on top for the VM build alone.
  #
  # The real config deliberately sets no password (see modules/common), which
  # would leave the VM stuck at the greeter with no way in. These throwaway
  # credentials make the greeter testable. They are plaintext in the store,
  # which is exactly why they live here and not in the real configuration.
  virtualisation.vmVariant = {
    users.users.sergiusens.initialPassword = "vm";
    users.users.root.initialPassword = "vm";

    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 16384;
      # Enough room for the greeter and Hyprland to be judged honestly.
      resolution = {
        x = 1920;
        y = 1200;
      };
    };

    # The host's camera, printer and backup target do not exist in a VM, and
    # the ipu6 stack builds an out-of-tree kernel module for no purpose here.
    hardware.ipu6.enable = lib.mkForce false;
    services.printing.enable = lib.mkForce false;
  };

}
