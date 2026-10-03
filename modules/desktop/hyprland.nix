# Hyprland session. Replaces the GNOME desktop the Bluefin images shipped.
#
# System-level pieces only: the compositor, the greeter, portals, and the
# session utilities. Per-user appearance and keybinds live in
# home/sergiusens/hyprland.nix.
{ pkgs, ... }:
{
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
  # tuigreet on a TTY: no second desktop stack dragged in just to log in, and it
  # cannot itself fail to start a Wayland session.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = toString [
        "${pkgs.greetd.tuigreet}/bin/tuigreet"
        "--time"
        "--remember"
        "--remember-user-session"
        "--asterisks"
        "--cmd 'uwsm start hyprland-uwsm.desktop'"
      ];
      user = "greeter";
    };
  };

  # Keeps the greeter from being scribbled over by kernel messages.
  boot.kernelParams = [ "quiet" ];

  # Unlock the login keyring with the login password, as GNOME did.
  security.pam.services.greetd.enableGnomeKeyring = true;
  # hyprlock authenticates against PAM; without this it can never unlock.
  security.pam.services.hyprlock = { };

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
    waybar
    mako # notifications
    fuzzel # launcher
    hyprpaper # wallpaper
    hyprlock # screen lock
    hypridle # idle management
    hyprpolkitagent # graphical auth prompts
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

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };
}
