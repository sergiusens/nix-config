# kynes — work laptop.
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
    ../../modules/work/falcon-sensor.nix
    ../../modules/work/kolide.nix
  ];

  # Both managed-endpoint agents are off. They are unpacked stubs, not working
  # modules — read the header comments in each before enabling. Until they work,
  # this host is not a compliant managed endpoint, which may well be a reason to
  # keep it on bootc instead.
  fleet.falcon.enable = false;
  fleet.kolide.enable = false;

  environment.systemPackages = with pkgs; [
    google-chrome # unfree; was installed from Google's RPM repo on bluefin-xp
  ];

  # No printing module: the HP scanner lives with leto.
}
