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

  # Flatpak kept as an escape hatch for apps not worth packaging.
  services.flatpak.enable = true;

  # Needed by Chrome and anything else storing secrets.
  services.gnome.gnome-keyring.enable = true;
}
