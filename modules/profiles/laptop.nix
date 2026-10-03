# Shared laptop profile. Both NixOS hosts in the fleet are laptops: leto is a
# Dell XPS 13 Plus 9320 and kynes is work-issued.
{ pkgs, ... }:
{
  # power-profiles-daemon rather than TLP. The two conflict — enabling both
  # gives you two daemons fighting over the same sysfs knobs — and PPD is what
  # desktop power-mode toggles (including the waybar module) talk to.
  services.power-profiles-daemon.enable = true;
  powerManagement.enable = true;

  # Intel thermal management; meaningful on a 28 W P-series part in a 13" chassis.
  services.thermald.enable = true;

  services.upower.enable = true;

  # NOTE: logind options moved under services.logind.settings in recent NixOS.
  # If this errors against the pinned nixpkgs, the older spelling is
  # services.logind.lidSwitch = "suspend";
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "suspend";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };
  services.blueman.enable = true;

  # Firmware updates — the XPS gets them through LVFS.
  services.fwupd.enable = true;

  # Trim the SSD weekly; NVMe plus LUKS with allowDiscards.
  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    powertop
    acpi
  ];
}
