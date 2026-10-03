# PLACEHOLDER — not a generated file.
#
# Replace wholesale with the output of, run on kynes itself:
#   nixos-generate-config --show-hardware-config
#
# The filesystem below exists only so `nix flake check` and package-level work
# can proceed. A system built from this will not boot.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  hardware.enableRedistributableFirmware = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/REPLACE-ME";
    fsType = "btrfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/REPLACE-ME-ESP";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  warnings = [
    "hosts/kynes/hardware-configuration.nix is a placeholder; regenerate it on the real machine before installing."
  ];

  _module.args = { };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
