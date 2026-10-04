# Things only a machine with a screen and a human at it needs.
#
# Split out of modules/common when thufir arrived: a headless server has no use
# for an audio stack, desktop fonts, Flatpak or a login keyring, and carrying
# them would mean a larger closure and more to update for no benefit.
{ pkgs, ... }:
{
  # --------------------------------------------------------------------- audio --
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # --------------------------------------------------------------------- fonts --
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      inter
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Inter" ];
      monospace = [ "JetBrainsMono Nerd Font" ];
    };
  };

  # --------------------------------------------------------------- localsend --
  # Fleet-wide default on anything with a screen, rather than part of the
  # heavier desktop-apps set: the lighter profiles the family machines will get
  # still need to send files to and from the phones, and a share target is only
  # useful if every machine has it.
  #
  # Not in modules/common, because thufir is headless and LocalSend is a GUI
  # application; move it there if the server ever needs to receive.
  environment.systemPackages = [ pkgs.localsend ];

  networking.firewall = {
    # Discovery is multicast UDP; transfers are TCP. Both on 53317, and both
    # required — without the UDP port the machine never appears in anyone's
    # device list even though receiving would work.
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };

  # Flatpak kept as an escape hatch for apps not worth packaging.
  services.flatpak.enable = true;

  # Needed by Chrome and anything else storing secrets.
  services.gnome.gnome-keyring.enable = true;
}
