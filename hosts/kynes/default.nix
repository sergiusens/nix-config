# kynes — Lenovo ThinkPad X1 Carbon Gen 13 (21NS005GAR). Chainguard-issued work
# laptop; replaces eregion, which ran bluefin-dx on this same machine.
#
# Intel Core Ultra 7 258V (Lunar Lake, 4P+4E), Arc 140V graphics (Xe2),
# Intel NPU, 32 GB LPDDR5X (30 GiB usable), 1 TB Samsung 9100 PRO NVMe, Intel
# BE200 Wi-Fi 7 and Bluetooth, Thunderbolt 4. UEFI, TPM 2.0. Inspected on the
# running machine under Bluefin, 2026-10-06.
#
# Model quirks come from nixos-hardware's lenovo-thinkpad-x1-13th-gen, wired up
# in flake.nix. It selects the xe GPU driver, which Lunar Lake requires.
{ lib, pkgs, ... }:
{
  imports = [
    ./disko.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/dank.nix # DankMaterialShell, same as leto
    ../../modules/hardware/intel-graphics.nix
    ../../modules/hardware/secure-boot.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/desktop.nix # audio, fonts, flatpak, keyring
    ../../modules/profiles/desktop-apps.nix # the shared application set
    ../../modules/work/compliance.nix
  ];

  # Deliberately NOT imported from leto:
  #   hardware/ipu6-camera.nix — this machine's camera is a plain UVC device on
  #     USB (Luxvisions 30c9:005f), not an IPU sensor. It works with no driver.
  #   hardware/printing.nix — the HP printer and scanner live with leto.
  #   hardware/dock-sleep-guard.nix — written for leto's dock.

  # Turn on once secrets/compliance.yaml is a real sops-encrypted file holding
  # kolide, falcon-cid and falcon-repo. See modules/work/compliance.nix and
  # modules/work/ATTRIBUTION.md. The Kolide posture in that module (no sshd,
  # Tailscale routes, Dirty Frag) applies regardless of this flag.
  #
  # Falcon additionally needs a one-off imperative bootstrap, since the sensor
  # cannot be packaged declaratively:
  #   gh auth login
  #   falcon-sensor-install
  # The service carries ConditionPathExists=/opt/CrowdStrike/falcond, so it
  # stays inert rather than failing until that has run.
  #
  # The kernel stays on the NixOS default (6.18 LTS, see modules/common). The
  # sensor drops into Reduced Functionality Mode on kernels CrowdStrike does
  # not yet support, and IT's update policy runs one sensor release behind.
  work.compliance.enable = false;

  # ------------------------------------------------------------------ hardware --
  # Taken from the running machine rather than nixos-generate-config, which
  # cannot run on Bluefin: NVMe directly on PCIe (no Intel VMD on this
  # platform), USB-C/Thunderbolt xHCI, and USB storage for the installer stick.
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "uas"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # BE200 Wi-Fi, SOF audio DSP, xe GuC/HuC and the NPU all load firmware
  # blobs from linux-firmware.
  hardware.enableRedistributableFirmware = true;

  # Thunderbolt device authorization, as on leto. Fedora enabled it by default.
  services.hardware.bolt.enable = true;

  # -------------------------------------------------------------- fingerprint --
  # Goodix 27c6:658c, supported by libfprint's goodixmoc driver. Enrol with
  # `fprintd-enroll` after the first login.
  #
  # Enabling fprintd adds pam_fprintd to every PAM service by default. That is
  # what sudo and polkit get. Two services are overridden:
  services.fprintd.enable = true;

  # The greeter: a fingerprint login gives PAM no password, so the GNOME
  # keyring (unlocked from the login password, see hyprland.nix) stays locked.
  security.pam.services.greetd.fprintAuth = false;

  # The DMS lock screen. DMS runs fingerprint in parallel with the password
  # field through its own bundled PAM stack. If pam_fprintd were also in its
  # password stack, the field would wait for the reader to time out. Declaring
  # this service is also what makes DMS use /etc/pam.d/dankshell at all.
  # Turn fingerprint on in DMS Settings -> Lock Screen.
  security.pam.services.dankshell.fprintAuth = false;

  # ---------------------------------------------------------------- containers --
  # Real Docker, as eregion ran (bluefin-dx ships docker-ce). Chainguard's
  # monorepo tooling assumes Docker semantics that rootless podman's shim does
  # not always honour. Podman stays installed; only its docker shim goes, since
  # it would claim the same `docker` command and socket.
  virtualisation.docker.enable = true;
  virtualisation.podman = {
    dockerCompat = lib.mkForce false;
    dockerSocket.enable = lib.mkForce false;
  };
  # Membership of docker is root-equivalent. It is what bluefin-dx did too.
  users.users.sergiusens.extraGroups = [ "docker" ];

  # ------------------------------------------------------------------ packages --
  # The shared set comes from modules/profiles/desktop-apps.nix. Only the
  # work-specific additions belong here; the developer CLI set is per-user in
  # home/sergiusens/work.nix.
  #
  # The photo stack (rapid-photo-downloader, ansel, rapidraw, siril, exiftool,
  # imagemagick) and shotcut stay on leto.
  environment.systemPackages = with pkgs; [
    # Unfree; was installed from Google's RPM repo on bluefin-xp. Kolide warns
    # three days after a Chrome release and blocks 11 days later, so rebuild
    # against a fresh nixpkgs at least weekly.
    google-chrome
    e2fsprogs # chattr, for `sbctl enroll-keys`; see modules/hardware/secure-boot.nix
  ];

  home-manager.users.sergiusens.imports = [ ../../home/sergiusens/work.nix ];

  # Chrome stays the default browser here while firefox is merely installed;
  # the association is picked from hostName in home/sergiusens/default.nix.

  # --------------------------------------------------------------- VM variant --
  # Same reasoning as leto's: the real config sets no password, so without this
  # the VM is stuck at the greeter. Applies only to
  # `nix build .#nixosConfigurations.kynes.config.system.build.vm`.
  virtualisation.vmVariant = {
    users.users.sergiusens.initialPassword = "vm";
    users.users.root.initialPassword = "vm";

    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 16384;
      resolution = {
        x = 1920;
        y = 1200;
      };
    };

    # No endpoint agents in a throwaway VM: Falcon needs an imperative
    # bootstrap and real secrets, and enrolling a VM with Kolide would register
    # a bogus device.
    work.compliance.enable = lib.mkForce false;
  };
}
