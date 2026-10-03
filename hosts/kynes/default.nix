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
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/hardware/intel-graphics.nix
    ../../modules/profiles/laptop.nix
    ../../modules/work/policy.nix
  ];

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

  environment.systemPackages = with pkgs; [
    google-chrome # unfree; was installed from Google's RPM repo on bluefin-xp
  ];

  # No printing module: the HP scanner lives with leto.
}
