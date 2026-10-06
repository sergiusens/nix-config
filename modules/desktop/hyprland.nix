# Hyprland session. Replaces the GNOME desktop the Bluefin images shipped.
#
# System-level pieces only: the compositor, the greeter, portals, and the
# session utilities. Per-user appearance and keybinds live in
# home/sergiusens/hyprland.nix.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.dank-greeter.nixosModules.dank-greeter ];

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
  # dank-greeter (programs.dms-greeter): a greetd frontend built on quickshell,
  # from the same project as DMS. It launches compositor.name directly rather
  # than hunting through a session-file search path, and configHome copies the
  # live DMS settings/colors into its cache dir so the login screen matches the
  # real desktop's theme and wallpaper. Replaces ReGreet.
  programs.dms-greeter = {
    enable = true;
    compositor.name = "hyprland";
    configHome = "/home/sergiusens";
  };

  # Read by the greeter module to own its state directory and assert the user
  # exists; the base services.greetd module creates it.
  services.greetd.settings.default_session.user = "greeter";

  # Keeps the greeter from being scribbled over by kernel messages.
  boot.kernelParams = [ "quiet" ];

  # Unlock the login keyring with the login password, as GNOME did.
  security.pam.services.greetd.enableGnomeKeyring = true;
  # DMS provides the lockscreen now. Its PAM configuration is declared by the
  # dms-shell module; hyprlock's stanza is gone with hyprlock.

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
    # and wallpaper all come from DankMaterialShell now; see
    # modules/desktop/dank.nix. Removed from here: waybar, mako, fuzzel,
    # hyprpaper, hyprlock, hypridle, hyprpolkitagent.
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
