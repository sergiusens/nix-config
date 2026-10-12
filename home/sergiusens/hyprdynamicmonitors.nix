# Declarative, condition-matched monitor layouts for Hyprland: dock/undock,
# lid open/closed. Config and per-profile Hyprland snippets live alongside
# this file in ./hyprdynamicmonitors/.
{ inputs, ... }:
{
  imports = [ inputs.hyprdynamicmonitors.homeManagerModules.default ];

  home.hyprdynamicmonitors = {
    enable = true;
    configFile = ./hyprdynamicmonitors/config.toml;
    extraFiles = {
      "hyprdynamicmonitors/hyprconfigs" = ./hyprdynamicmonitors/hyprconfigs;
    };
    # Lid events need the daemon started with this flag; see the config.toml
    # comment for what the old lid-switch bindl this replaces used to do.
    extraFlags = [ "--enable-lid-events" ];
  };

  # hyprdynamicmonitors only ever symlinks INTO config.d/, it never creates
  # the directory itself (its "prepare" boot unit just removes a stale
  # destination file if one exists — "file does not exist" is a logged no-op,
  # not directory creation). Without this, the service fatals on startup with
  # "no such file or directory" and crash-loops forever, so the monitors file
  # this sources below never gets written.
  home.file.".config/hypr/config.d/.keep".text = "";

  # Glob, not a literal filename: the destination file does not exist until
  # hyprdynamicmonitors actually runs and generates it, and a literal path to
  # a file that is not there yet is a hard "globbing error" at Hyprland
  # startup. An empty glob match is not an error.
  wayland.windowManager.hyprland.extraConfig = ''
    source = ~/.config/hypr/config.d/*.conf
  '';
}
