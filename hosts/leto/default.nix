# leto — Dell XPS 13 Plus 9320. Photo workstation.
#
# 13th Gen Intel Core i7-1360P (Raptor Lake-P), Iris Xe graphics, 30 GiB RAM,
# 1 TB NVMe, Intel AX211 wifi/bluetooth. UEFI, LUKS-on-btrfs.
#
# Hardware quirks come from nixos-hardware's dell-xps-13-9320 module, wired up
# in flake.nix rather than imported here.
{ pkgs, ... }:
{
  imports = [
    ./disko.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/hardware/intel-graphics.nix
    ../../modules/hardware/printing.nix
    ../../modules/profiles/laptop.nix
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

  # NOTE: hibernation needs boot.resumeDevice plus the swapfile's physical
  # offset, which only exists once the file does:
  #   sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
  # then set boot.kernelParams = [ "resume_offset=<N>" ] and
  # boot.resumeDevice = "/dev/mapper/cryptroot". Not configured yet.

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
  environment.systemPackages = with pkgs; [
    # Photo workflow. rapid-photo-downloader is the one carried over from the
    # Bluefin image, where it came from a COPR.
    rapid-photo-downloader
    darktable
    gimp
    exiftool
    imagemagick

    # Were flatpak preinstalls on the Bluefin image; both are in nixpkgs.
    localsend
    nextcloud-client
  ];

  networking.firewall = {
    # LocalSend needs these to discover and receive from phones on the LAN.
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };
}
