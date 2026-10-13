# Hyprland session. Replaces the GNOME desktop the Bluefin images shipped.
#
# System-level pieces only: the compositor, the greeter, portals, and the
# session utilities. Per-user appearance and keybinds live in
# home/sergiusens/hyprland.nix.
{ inputs, config, lib, pkgs, ... }:
{
  imports = [
    ./shell.nix
    inputs.dank-greeter.nixosModules.dank-greeter
    inputs.noctalia-greeter.nixosModules.default
  ];

  programs.hyprland = {
    enable = true;
    # uwsm (Universal Wayland Session Manager) starts the compositor inside a
    # proper systemd user session. Without it, systemd user units, dbus
    # activation and the xdg portals all start in a half-initialised
    # environment, which is the usual cause of "portals don't work on Hyprland".
    withUWSM = true;
    xwayland.enable = true;
  };

  # ------------------------------------------------------------------- greeter --
  # Both greeters are always imported (see the imports list above); only one
  # is ever enabled, gated on desktop.shell the same way as the shells
  # themselves in dank.nix/noctalia.nix.

  # dank-greeter (programs.dms-greeter): a greetd frontend built on quickshell,
  # from the same project as DMS. It launches compositor.name directly rather
  # than hunting through a session-file search path, and configHome copies the
  # live DMS settings/colors into its cache dir so the login screen matches the
  # real desktop's theme and wallpaper. Replaces ReGreet.
  programs.dms-greeter = lib.mkIf (config.desktop.shell == "dms") {
    enable = true;
    compositor.name = "hyprland";
    configHome = "/home/sergiusens";
  };

  # noctalia-greeter: the equivalent for Noctalia, same relationship to it as
  # dank-greeter has to DMS. Unlike dank-greeter it picks a session from a
  # session-file search path rather than launching a compositor directly, so
  # `session.default` names a session file (or its .desktop filename), not a
  # compositor binary -- "hyprland" is the expected name given
  # programs.hyprland.withUWSM = true above, but has not yet been confirmed
  # against what NixOS actually installs; check `noctalia-greeter sessions`
  # (or just watch it boot) the first time this is live.
  #
  # The full [appearance.palette] here mirrors home/sergiusens/noctalia.nix's
  # NordLight.light palette directly rather than depending on `noctalia msg
  # greeter-sync` (a runtime command, not Nix-managed) -- a declaratively
  # complete palette always wins over whatever Sync last wrote to sync.toml,
  # per noctalia-greeter's own docs, so this stays correct without that extra
  # moving part.
  services.displayManager.noctalia-greeter = lib.mkIf (config.desktop.shell == "noctalia") {
    enable = true;
    settings = {
      session.default = "hyprland";
      appearance = {
        scheme = "Synced";
        theme_mode = "light";
        palette = {
          primary = "#5E81AC";
          on_primary = "#ECEFF4";
          secondary = "#81A1C1";
          on_secondary = "#2E3440";
          tertiary = "#88C0D0";
          on_tertiary = "#2E3440";
          error = "#BF616A";
          on_error = "#ECEFF4";
          surface = "#ECEFF4";
          on_surface = "#2E3440";
          surface_variant = "#D8DEE9";
          on_surface_variant = "#434C5E";
          outline = "#4C566A";
          shadow = "#D8DEE9";
          hover = "#D8DEE9";
          on_hover = "#2E3440";
        };
      };
    };
  };

  # Read by both greeters to own their state directory and assert the user
  # exists; the base services.greetd module creates it.
  services.greetd.settings.default_session.user = "greeter";

  # Keeps the greeter from being scribbled over by kernel messages.
  boot.kernelParams = [ "quiet" ];

  # Unlock the login keyring with the login password, as GNOME did.
  security.pam.services.greetd.enableGnomeKeyring = true;
  # The active shell provides the lockscreen. DMS's PAM configuration is
  # declared by the dms-shell module; Noctalia's by its own home-manager
  # module (see hosts/kynes/default.nix for the fingerprint-vs-password-field
  # PAM override this requires on kynes). hyprlock's stanza is gone either way.

  # ------------------------------------------------------------------- portals --
  # programs.hyprland already provides xdg-desktop-portal-hyprland (screencast,
  # screenshot). The GTK portal is added for the file chooser, which is what
  # Chrome and the Nextcloud client actually use.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  security.polkit.enable = true;
  programs.dconf.enable = true;

  # Mounting, trash and network shares for the file manager.
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.tumbler.enable = true;

  environment.systemPackages = with pkgs; [
    # --- terminal ---------------------------------------------------------
    ghostty
    # Rescue terminal. ~2 MB, starts in single-digit milliseconds, shares none
    # of ghostty's GTK/GPU dependencies. Bound to a separate key in the Hyprland
    # config so a broken primary terminal is an inconvenience, not a lockout.
    foot

    # --- session ----------------------------------------------------------
    # The panel, launcher, notifications, lock, idle, polkit agent, clipboard
    # and wallpaper all come from the active shell now (DMS or Noctalia, per
    # desktop.shell -- see modules/desktop/dank.nix and
    # home/sergiusens/noctalia.nix; Noctalia needs no system-level module of
    # its own, its home-manager module is self-contained). Removed from
    # here: waybar, mako, fuzzel, hyprpaper, hyprlock, hypridle,
    # hyprpolkitagent.
    hyprcursor

    # --- screenshots and clipboard ----------------------------------------
    grim
    slurp
    hyprshot
    wl-clipboard
    cliphist

    # --- controls ---------------------------------------------------------
    brightnessctl
    playerctl
    pamixer
    pavucontrol
    networkmanagerapplet
    wlr-randr

    # --- files ------------------------------------------------------------
    nautilus
    file-roller

    # --- theming ----------------------------------------------------------
    adwaita-icon-theme
    papirus-icon-theme
  ];

  # Wayland-native by default; fall back to XWayland only where required.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Chrome/Electron under Wayland
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  # platformTheme = "gnome" bridges Qt apps to the GTK theme (now Nordic /
  # Nordic-Polar, home/sergiusens/default.nix), so they inherit real Nord
  # colors through that; style is the QStyle name layered on top, and there
  # is no genuine Nord QStyle, so this just follows the same dark/light
  # split as everything else.
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = if config.desktop.shell == "noctalia" then "adwaita" else "adwaita-dark";
  };
}
