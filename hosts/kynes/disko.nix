# Declarative disk layout for kynes (ThinkPad X1 Carbon Gen 13, 1 TB Samsung
# 9100 PRO NVMe).
#
# INERT during `nixos-rebuild` — this only generates the fileSystems and
# swapDevices entries. A disk is touched solely by an explicit `disko` run,
# which DESTROYS everything on the device. See INSTALL.md.
#
# Same shape as hosts/leto/disko.nix: one 2 GB ESP, LUKS, btrfs subvolumes.
# Under Bluefin (as eregion) this disk had a 600 MB ESP, a 2 GB ext4 /boot and
# LUKS+btrfs, so the partition table is rewritten, not reused.
#
# LUKS is not optional on this host: Kolide's "Linux Disk Encryption" check
# blocks sign-in to Chainguard apps on an unencrypted disk.
{
  disko.devices.disk.main = {
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings = {
              allowDiscards = true;
              # Tries the TPM before the passphrase. Inert until a TPM keyslot
              # is enrolled, which must come AFTER Secure Boot is set up. See
              # modules/hardware/secure-boot.nix.
              crypttabExtraOpts = [ "tpm2-device=auto" ];
            };
            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "kynes"
              ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                # Two-tier swap, slow tier. 32 GiB against 30 GiB of RAM: room
                # to spill container builds, and >= RAM so suspend-then-
                # hibernate is possible. This machine, like leto, offers only
                # s2idle (/sys/power/mem_sleep -> [s2idle]).
                "@swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = "32G";
                };
              };
            };
          };
        };
      };
    };
  };
}
