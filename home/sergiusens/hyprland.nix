# Hyprland user configuration: appearance, input, keybinds.
#
# The compositor itself is installed system-wide by
# modules/desktop/hyprland.nix, so package and portalPackage are null here —
# setting them would install a second Hyprland that disagrees with the session
# the greeter actually starts.
{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;

    settings = {
      # ------------------------------------------------------------- monitors --
      # XPS 13 Plus 9320 ships in FHD+ (1920x1200), OLED 3.5K (3456x2160) and
      # UHD+ (3840x2400) variants. `preferred,auto,auto` lets Hyprland pick the
      # native mode and a sensible integer-ish scale; replace with an explicit
      # line once you see what `hyprctl monitors` reports.
      monitor = [
        ",preferred,auto,auto"
      ];

      # ---------------------------------------------------------------- input --
      input = {
        # Latin American layout, matching the hardware. Hyprland does not read
        # services.xserver.xkb — this is the setting that governs the session.
        kb_layout = "latam";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
        };
        sensitivity = 0;
      };

      gestures.workspace_swipe = true;

      # ----------------------------------------------------------- appearance --
      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        resize_on_border = true;
        layout = "dwindle";
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
        };
        shadow.enabled = true;
      };

      animations = {
        enabled = true;
        bezier = [ "easeOutQuint,0.23,1,0.32,1" ];
        animation = [
          "windows,1,4,easeOutQuint"
          "fade,1,3,default"
          "workspaces,1,4,easeOutQuint,slide"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        # Photo work: do not let the compositor pick a different colour
        # management path per-surface while editing. See the colour management
        # caveat in README.md.
        vrr = 0;
      };

      # -------------------------------------------------------------- autostart --
      exec-once = [
        "uwsm app -- hyprpaper"
        "uwsm app -- waybar"
        "uwsm app -- mako"
        "systemctl --user start hyprpolkitagent"
        "wl-paste --watch cliphist store"
      ];

      # --------------------------------------------------------------- keybinds --
      "$mod" = "SUPER";

      bind = [
        # Terminals. ghostty is primary; foot is the rescue terminal and shares
        # none of ghostty's GPU/GTK dependencies, so a broken primary terminal
        # does not lock you out of the session.
        "$mod, Return, exec, uwsm app -- ghostty"
        "$mod SHIFT, Return, exec, uwsm app -- foot"

        "$mod, D, exec, uwsm app -- fuzzel"
        "$mod, E, exec, uwsm app -- nautilus"
        "$mod, Q, killactive,"
        "$mod SHIFT, E, exit,"
        "$mod, L, exec, loginctl lock-session"
        "$mod, V, togglefloating,"
        "$mod, F, fullscreen,"
        "$mod, P, pseudo,"
        "$mod, J, togglesplit,"

        # Clipboard history
        "$mod SHIFT, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"

        # Screenshots
        ", Print, exec, hyprshot -m output"
        "$mod, Print, exec, hyprshot -m region"
        "$mod SHIFT, Print, exec, hyprshot -m window"

        # Focus
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Move windows
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
      ]
      ++ (
        # Workspaces 1-9: $mod+N to switch, $mod+SHIFT+N to move
        builtins.concatLists (
          builtins.genList (
            i:
            let
              n = toString (i + 1);
            in
            [
              "$mod, ${n}, workspace, ${n}"
              "$mod SHIFT, ${n}, movetoworkspace, ${n}"
            ]
          ) 9
        )
      );

      # Repeat while held
      binde = [
        ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
      ];

      # Work even when the screen is locked
      bindl = [
        ", XF86AudioMute, exec, pamixer -t"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      # TODO: point at a real wallpaper; one of your own photographs would be
      # the obvious choice for this machine.
      preload = [ ];
      wallpaper = [ ];
    };
  };
}
