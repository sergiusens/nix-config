# Declarative disk layout for leto (Dell XPS 13 Plus 9320, 1 TB NVMe).
#
# INERT during `nixos-rebuild` — this only generates the fileSystems and
# swapDevices entries. A disk is touched solely by an explicit `disko` run,
# which DESTROYS everything on the device. See README.md.
#
# Mirrors the LUKS-on-btrfs shape the machine already had under Bluefin, minus
# the ostree subvolume scheme, plus a dedicated swap subvolume.
{
  disko.devices.disk.main = {
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          # Bluefin used a cramped 600 MB ESP plus a separate 2 GB /boot, which
          # ostree needed. systemd-boot puts kernels and initrds directly on the
          # ESP, so it wants one roomy partition instead: 10 generations of
          # kernel + initrd is comfortably over 1 GB.
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

              # Lets systemd-cryptsetup try the TPM before asking for a
              # passphrase. Harmless until something is actually enrolled —
              # with no TPM keyslot present it simply falls through to the
              # passphrase prompt — so it is safe to carry from the start.
              #
              # Enrolment itself writes to the LUKS header and cannot be
              # declarative; see INSTALL.md. Requires
              # boot.initrd.systemd.enable, which modules/common already sets.
              crypttabExtraOpts = [ "tpm2-device=auto" ];
            };
            content = {
              type = "btrfs";
              extraArgs = [ "-L" "leto" ];
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

                # /nix benefits most from compression and never wants atimes.
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                # Two-tier swap, slow tier. 64 GiB against 30 GiB of RAM:
                #   - real overflow room for photo work, which is what was
                #     actually missing (zram adds no capacity)
                #   - >= RAM, so suspend-to-disk becomes possible later
                #   - 6.7% of a 1 TB disk, against 443 GB currently free
                #
                # A btrfs swapfile must be nodatacow, uncompressed, and outside
                # any snapshotted subvolume — hence its own subvolume. disko
                # handles those flags; creating one by hand needs `chattr +C` on
                # the empty file *before* writing to it.
                "@swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = "64G";
                };
              };
            };
          };
        };
      };
    };
  };
}
