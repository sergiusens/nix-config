# leto — Dell XPS 13 Plus 9320. Photo workstation.
#
# 13th Gen Intel Core i7-1360P (Raptor Lake-P), Iris Xe graphics, 30 GiB RAM,
# 1 TB NVMe, Intel AX211 wifi/bluetooth. UEFI, LUKS-on-btrfs.
#
# Hardware quirks come from nixos-hardware's dell-xps-13-9320 module, wired up
# in flake.nix rather than imported here.
{ lib, pkgs, ... }:
{
  imports = [
    ./disko.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/dank.nix
    ../../modules/hardware/intel-graphics.nix
    ../../modules/hardware/ipu6-camera.nix
    ../../modules/hardware/printing.nix
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
  # The mitigation is suspend-then-hibernate: suspend normally, then write out
  # to disk and power off after a delay. Now worth doing, because the 64 GiB
  # swapfile added for the photo-OOM problem is comfortably larger than the
  # 30 GiB of RAM that hibernation needs to dump.
  #
  # TODO: hibernation needs the swapfile's physical offset, which only exists
  # once the file does. After the first boot:
  #   sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
  # then uncomment below with that number. Encrypted swap on LUKS is fine —
  # the initrd unlocks cryptroot before resuming.
  #
  # boot.resumeDevice = "/dev/mapper/cryptroot";
  # boot.kernelParams = [ "resume_offset=<N>" ];
  # systemd.sleep.extraConfig = ''
  #   HibernateDelaySec=90min
  # '';
  # services.logind.settings.Login.HandleLidSwitch = lib.mkForce "suspend-then-hibernate";

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
  ];
  boot.kernelModules = [ "kvm-intel" ];
  hardware.enableRedistributableFirmware = true;

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

    # --- video --------------------------------------------------------------
    shotcut

    # --- games --------------------------------------------------------------
    luanti # this host only; also self-hosted on thufir
  ];

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
      # Enough room for ReGreet and Hyprland to be judged honestly.
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
