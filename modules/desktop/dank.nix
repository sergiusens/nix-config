# DankMaterialShell — the desktop shell for Hyprland.
#
# DMS is not a status bar with extras; it is a shell. It provides the panel,
# the spotlight launcher, notifications, the lockscreen, idle handling, a
# polkit agent, clipboard history, wallpaper and a power menu. Everything it
# supplies has been removed from modules/desktop/hyprland.nix and
# home/sergiusens/* rather than left running alongside — two notification
# daemons or two launchers is the same class of fault as the two waybars.
#
# Control surface is `dms ipc call <target> <verb>`; the keybinds in
# home/sergiusens/hyprland.nix are translated from the project's own
# core/internal/config/embedded/hypr-binds.lua.
#
# NOTE: upstream ships those binds as Hyprland **Lua**, since DMS targets
# Hyprland 0.55+'s Lua config. We are pinned to hyprlang (see
# home/sergiusens/hyprland.nix), so they are translated by hand. That is one
# more reason the Lua migration is worth doing deliberately.
{ inputs, ... }:
{
  imports = [ inputs.dms.nixosModules.dank-material-shell ];

  programs.dms-shell = {
    enable = true;

    # Start the shell with the graphical session instead of from exec-once.
    systemd.enable = true;

    # CPU, RAM and temperature widgets, via the bundled dgop.
    enableSystemMonitoring = true;

    # Recolours the shell from the current wallpaper.
    enableDynamicTheming = true;

    enableClipboardPaste = true;
    enableCalendarEvents = true;

    # Off deliberately: no VPN on this host, and the audio wavelength widget is
    # a continuous visualiser that costs battery on a laptop for decoration.
    enableVPN = false;
    enableAudioWavelength = false;
  };

  # The greeter is a separate project (programs.dms-greeter from
  # github:AvengeMedia/dank-greeter), wired in modules/desktop/hyprland.nix.
}
