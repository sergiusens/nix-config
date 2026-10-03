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
  # ReGreet: a GTK4/libadwaita greeter for greetd, run inside cage (a minimal
  # Wayland kiosk compositor). Chosen over tuigreet because this is a HiDPI
  # laptop and a TTY greeter renders at console font size — legible only with a
  # hand-tuned console font. Chosen over GDM/SDDM because it needs neither GNOME
  # nor Qt.
  #
  # The NixOS module sets services.greetd.enable and the default_session command
  # itself, both with mkDefault — so do NOT also set a command here, or it will
  # silently win and launch something else.
  programs.regreet = {
    enable = true;

    # Matches the GTK theming in home/sergiusens: Adwaita-dark with Papirus
    # icons and Inter, so the greeter and the session agree.
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    cursorTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };
    font = {
      package = pkgs.inter;
      name = "Inter";
      size = 14;
    };

    settings = {
      # The module fills in GTK.theme_name / icon_theme_name / font_name /
      # cursor_theme_name from the options above, but not this one.
      GTK.application_prefer_dark_theme = true;

      commands = {
        reboot = [
          "systemctl"
          "reboot"
        ];
        poweroff = [
          "systemctl"
          "poweroff"
        ];
      };
    };
  };

  # The greeter's own session user; the regreet module reads this to own
  # /var/lib/regreet and asserts the user exists.
  services.greetd.settings.default_session.user = "greeter";

  # ReGreet's session search path is baked in at compile time as
  # /usr/share/xsessions:/usr/share/wayland-sessions, and nixpkgs does not
  # override it — there is no SESSION_DIRS handling in its package.nix. Neither
  # path exists on NixOS, so without this the session dropdown can come up
  # empty. Point it at where NixOS actually puts session files.
  #
  # Not a lockout risk even if it fails: ReGreet allows typing a session command
  # by hand, so `uwsm start hyprland-uwsm.desktop` always gets you in.
  #
  # VERIFY on first boot that Hyprland appears in the session dropdown.
  systemd.services.greetd.environment.SESSION_DIRS = "/run/current-system/sw/share/wayland-sessions";

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
