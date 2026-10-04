# HP printer and scanner support, including the proprietary HPLIP plugin.
#
# Confirmed wanted on leto — not an unexamined carry-over from bluefin-xp,
# unlike nextcloud-client, darktable and gimp, which were removed.
#
# This is the clearest win of the move to NixOS. bluefin-xp carried the plugin
# as a hand-assembled binary overlay committed into the image — prebuilt .so
# files under /usr/lib64/sane, firmware blobs, a pycache, and a
# hplip-plugin-state.service to sync state because /usr is read-only on bootc.
# All of it collapses into one attribute here: hplipWithPlugin fetches and wires
# the plugin itself.
{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    drivers = [ pkgs.hplipWithPlugin ];
  };

  # Driverless discovery of network printers.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.hplipWithPlugin ];
  };

  # udev rules so the scanner is reachable without root; membership in the
  # "scanner" and "lp" groups is granted in modules/common.
  services.udev.packages = [ pkgs.hplipWithPlugin ];

  environment.systemPackages = with pkgs; [
    simple-scan
    system-config-printer
  ];
}
