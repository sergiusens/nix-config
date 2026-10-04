# PLACEHOLDER — not a generated file.
#
# Replace wholesale with the output of, run on the real orthanc/thufir machine:
#   nixos-generate-config --show-hardware-config
#
# Also confirm there what the LAN interface is actually called: orthanc.bu named
# enp0s20f0u3, which is a USB-attached NIC and therefore a name that can change.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  hardware.enableRedistributableFirmware = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/REPLACE-ME";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/REPLACE-ME-ESP";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  warnings = [
    "hosts/thufir/hardware-configuration.nix is a placeholder; regenerate it on the real machine before installing."
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
