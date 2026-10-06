# A custom NixOS installer ISO for this fleet.
#
# The point is that an install should not require remembering a procedure. The
# ISO carries this repository, the tools the procedure needs, and a script that
# runs it in the right order — including the parts that are easy to get wrong
# or out of sequence, like Secure Boot before TPM enrolment.
#
# Build:
#   nix build .#installer-iso
#   ls result/iso/*.iso
#
# Write it with `dd` or Impression; it is a hybrid ISO.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIAe2M8f3VTe9BrhfnemaHHKYDnmrzPTZJ3LnXWVK56H";

  # The procedure, as a program rather than a document. Refuses to do anything
  # destructive without the host name typed back.
  installHost = pkgs.writeShellApplication {
    name = "install-fleet-host";
    runtimeInputs = with pkgs; [
      coreutils
      disko
      nixos-install-tools
      util-linux
      gnugrep
      sbctl
    ];
    text = ''
      FLAKE=''${FLAKE:-/etc/nix-config}
      HOST=''${1:-}

      if [[ -z "$HOST" ]]; then
        echo "usage: install-fleet-host <leto|kynes|thufir>"
        echo
        echo "Installs from $FLAKE. Set FLAKE= to install from somewhere else,"
        echo "for example github:sergiusens/nix-config"
        exit 2
      fi

      echo "=== plan ==="
      echo "  host      : $HOST"
      echo "  flake     : $FLAKE"
      echo

      if [[ ! -e "$FLAKE/hosts/$HOST/disko.nix" ]]; then
        echo "No disko.nix for '$HOST'. Partition by hand, mount at /mnt, then:"
        echo "  nixos-install --flake $FLAKE#$HOST"
        exit 1
      fi

      DISK=$(grep -oE '/dev/[a-z0-9]+' "$FLAKE/hosts/$HOST/disko.nix" | head -1)
      echo "This will ERASE $DISK completely."
      lsblk "$DISK" || true
      echo
      read -r -p "Type the host name ($HOST) to continue: " confirm
      [[ "$confirm" == "$HOST" ]] || { echo "aborted"; exit 1; }

      echo "=== partitioning (disko) ==="
      echo "If anything below this point fails, do NOT rerun this script:"
      echo "disko would reformat the disk you just installed to. Mount by"
      echo "hand instead and finish manually -- see the recovery recipe in"
      echo "INSTALL.md on this ISO (/etc/nix-config/INSTALL.md)."
      disko --mode destroy,format,mount --flake "$FLAKE#$HOST"

      echo "=== secure boot keys ==="
      # lanzaboote signs the UKI during nixos-install itself, so the sbctl
      # keys must already exist on the target -- creating them afterwards is
      # too late and nixos-install fails looking for db.pem.
      sbctl create-keys
      install -d -m 700 /mnt/var/lib
      cp -a /var/lib/sbctl /mnt/var/lib/sbctl
      test -e /mnt/var/lib/sbctl/keys/db/db.pem || { echo "sbctl keys missing"; exit 1; }

      echo "=== installing ==="
      nixos-install --flake "$FLAKE#$HOST"

      cat <<'NEXT'

      ====================== after rebooting ======================
      1. Set your user password — the config ships without one:
           (log in as root on tty2)  passwd sergiusens

      2. Secure Boot, BEFORE the TPM. The keys already exist and generation 1
         is already signed -- nothing to create or rebuild here. Order
         matters: PCR 7 measures Secure Boot state, so enrolling the TPM
         first then enabling Secure Boot invalidates the policy.
           reboot -> firmware -> Secure Boot -> erase all Secure Boot keys /
                     reset to Setup Mode (disabling Secure Boot is NOT the
                     same thing and enroll-keys will fail)
           sudo chattr -i /sys/firmware/efi/efivars/{KEK,db}-*
           sudo sbctl enroll-keys --microsoft
           reboot -> sudo bootctl status
                     (plain `bootctl status` as a normal user prints
                     Permission denied reading /boot; use sudo)
                     expect "Secure Boot: enabled (deployed)"

      3. TPM unlock, with a recovery key FIRST:
           sudo systemd-cryptenroll --recovery-key <luks-partition>
           sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
                --tpm2-with-pin=yes <luks-partition>
         If Secure Boot keys or firmware settings change again later, PCR 7
         changes with them -- re-run cryptenroll with --wipe-slot=tpm2
         before re-enrolling, or you're locked out down to the recovery key.

      4. Back up /var/lib/sbctl somewhere off this machine. It's the only
         copy of the keys that sign every future generation.

      5. Restore ~/.claude, then rename the project directories, which
         are keyed by absolute path and move with /var/home -> /home:
           cd ~/.claude/projects
           for d in -var-home-sergiusens-*; do mv -- "$d" "''${d/-var-home-/-home-}"; done

      6. Verify what only real hardware can show: camera, OpenCL,
         suspend, printing, and colour management in darktable/Ansel.
         See INSTALL.md on this ISO at /etc/nix-config/INSTALL.md
      =============================================================
      NEXT
    '';
  };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  # The repository travels with the ISO, so an install needs no network and no
  # clone. `install-fleet-host` reads it from here by default.
  environment.etc."nix-config".source = ../../.;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # The minimal ISO defaults to wpa_supplicant; NetworkManager's nmtui is far
  # easier at an install prompt. They cannot both manage the radio.
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager.enable = true;

  # So the install can be driven from another machine rather than hunched over
  # the target. Root login by key only; this is a live ISO, there is no
  # password worth having.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];
  users.users.nixos.openssh.authorizedKeys.keys = [ sshKey ];

  environment.systemPackages = with pkgs; [
    installHost

    # the procedure's tools
    disko
    sbctl # Secure Boot keys
    tpm2-tools # TPM inspection
    cryptsetup
    nixos-install-tools

    # the usual company at an install prompt
    git
    gh
    helix
    jq
    curl
    rsync
    pciutils
    usbutils
    tmux
  ];

  # image.baseName, NOT image.fileName. The rename warning for the old
  # isoImage.isoName points at fileName, but that only feeds image.filePath,
  # which is metadata. iso-image.nix names the artifact from baseName:
  #     isoName = "''${config.image.baseName}.iso";
  # Setting fileName alone evaluates perfectly and still produces an ISO called
  # nixos-minimal-*.iso. Extension is appended, so none here.
  image.baseName = lib.mkForce "atreides-installer-${config.system.nixos.label}-x86_64";

  # zstd compresses a little worse than xz and builds a great deal faster,
  # which matters when the ISO is rebuilt after every config change.
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  # The installation media pulls in ZFS support, which warns unless this is
  # stated. false is the recommended value and becomes the default in 26.11;
  # nothing in this fleet uses ZFS.
  boot.zfs.forceImportRoot = false;

  # Shown on tty1 before the login prompt.
  services.getty.helpLine = lib.mkForce ''

    Atreides fleet installer.

      install-fleet-host leto     — partition, install, then print what to do next
      nmtui                       — wifi
      /etc/nix-config             — this repository, INSTALL.md included

    Nothing is destroyed until you type the host name to confirm.
  '';

  system.stateVersion = "26.05";
}
