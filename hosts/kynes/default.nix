# kynes — work laptop. Chainguard-issued; carries the endpoint compliance stack.
#
# ############################ HARDWARE UNKNOWN #############################
# The machine's model, disk layout and firmware mode have not been inspected.
# Before the first install, run on the machine itself:
#   nixos-generate-config --show-hardware-config > hosts/kynes/hardware-configuration.nix
# and check whether nixos-hardware has a module for it, then add it alongside
# leto's in flake.nix.
#
# The config below evaluates, but the placeholder filesystem in
# hardware-configuration.nix means it will NOT boot as-is.
# ###########################################################################
{ lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/dank.nix # DankMaterialShell, same as leto
    ../../modules/hardware/intel-graphics.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/desktop-apps.nix # the shared application set
    ../../modules/work/policy.nix
  ];

  # Deliberately NOT imported from leto:
  #   hardware/ipu6-camera.nix — specific to leto's OV01A10 behind the Raptor
  #     Lake IPU. This machine's camera is unknown; check `lspci | grep -i ipu`
  #     and `lsusb` on it before assuming anything.
  #   hardware/printing.nix — the HP printer and scanner live with leto.

  # Turn on once secrets/policy.yaml is a real sops-encrypted file holding
  # kolide, falcon-cid and falcon-repo. See modules/work/policy.nix and
  # modules/work/ATTRIBUTION.md.
  #
  # Falcon additionally needs a one-off imperative bootstrap, since the sensor
  # cannot be packaged declaratively:
  #   gh auth login
  #   falcon-sensor-install
  # The service carries ConditionPathExists=/opt/CrowdStrike/falcond, so it
  # stays inert rather than failing until that has run.
  fleet.policy.enable = false;

  # Intel graphics is assumed. If kynes turns out to be AMD, drop the
  # intel-graphics import above.

  # The shared set comes from modules/profiles/desktop-apps.nix. Only the
  # work-specific additions belong here.
  #
  # The photo stack (rapid-photo-downloader, ansel, rapidraw, siril, exiftool,
  # imagemagick) and shotcut stay on leto.
  environment.systemPackages = with pkgs; [
    google-chrome # unfree; was installed from Google's RPM repo on bluefin-xp
  ];

  # Chrome stays the default browser here while firefox is merely installed;
  # the association is picked from hostName in home/sergiusens/default.nix.

  # --------------------------------------------------------------- VM variant --
  # Same reasoning as leto's: the real config sets no password, so without this
  # the VM is stuck at the greeter. Applies only to
  # `nix build .#nixosConfigurations.kynes.config.system.build.vm`.
  #
  # Worth having despite the placeholder hardware-configuration.nix: qemu-vm
  # substitutes its own filesystems, so a kynes VM boots and the desktop can be
  # tested long before the real machine is touched.
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
    fleet.policy.enable = lib.mkForce false;
  };
}
