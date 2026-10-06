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

    # ######################### DO NOT DROP THIS LINE #########################
    # home-manager defaults configType by stateVersion: "hyprlang" below 26.05,
    # "lua" at 26.05 and above. Our stateVersion is 26.05, so without this the
    # module writes ~/.config/hypr/hyprland.lua — and everything below is
    # hyprlang syntax. The symptom is Hyprland booting into emergency mode with
    # "A lua config error resulted in no binds being registered" and
    # "<name> expected near '$'", because `$mod = SUPER` is not valid Lua.
    #
    # (If that ever happens, the emergency binds are SUPER+Q for a terminal,
    # SUPER+R for hyprland-run and SUPER+M to exit.)
    #
    # hyprlang still works and is still supported; it is simply the legacy
    # format now. Migrating to Lua is a real rewrite, not a translation:
    #   $mod = "SUPER"            ->  mod = { _var = "SUPER"; };
    #   general/decoration/input  ->  nested under `config`
    #   bind = [ "$mod, Q, ..." ] ->  bind = [ { _args = [ ... ]; } ] with
    #                                 hl.dsp.* dispatchers in mkLuaInline
    #   exec-once                 ->  on = { _args = [ "hyprland.start" fn ]; }
    # Worth doing deliberately, with the Hyprland Lua API to hand.
    # #########################################################################
    configType = "hyprlang";

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
          # Hyphens here, NOT underscores. The stubs list the *Lua* key as
          # input.touchpad.tap_to_click, but hyprlang spells this one
          # tap-to-click; using the Lua spelling makes Hyprland reject it with
          # "config option <input:touchpad:tap_to_click> does not exist".
          tap-to-click = true;
        };
        sensitivity = 0;
      };

      # gestures:workspace_swipe was removed in favour of a general `gesture`
      # keyword: fingers, direction, action. The gestures.workspace_swipe_*
      # tuning options still exist, only the master toggle moved.
      gesture = "3, horizontal, workspace";

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
        # dwindle:pseudotile no longer exists; pseudo is a dispatcher now and is
        # bound to $mod+P below.
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
      # Nothing to autostart. DankMaterialShell runs from its own systemd user
      # unit (programs.dms-shell.systemd.enable) and brings the polkit agent
      # and clipboard with it. Anything added here must NOT duplicate a
      # systemd user service, or you get two of it — the two-waybars fault.

      # --------------------------------------------------------------- keybinds --
      "$mod" = "SUPER";

      bind = [
        # Terminals. ghostty is primary; foot is the rescue terminal and shares
        # none of ghostty's GPU/GTK dependencies, so a broken primary terminal
        # does not lock you out of the session.
        "$mod, Return, exec, uwsm app -- ghostty"
        "$mod SHIFT, Return, exec, uwsm app -- foot"

        "$mod, D, exec, dms ipc call spotlight toggle"
        "$mod, E, exec, uwsm app -- nautilus"
        "$mod, Q, killactive,"
        "$mod SHIFT, E, exit,"
        "$mod, L, exec, dms ipc call lock lock"
        "$mod, V, togglefloating,"
        "$mod, F, fullscreen,"
        "$mod, P, pseudo,"
        # togglesplit is a dwindle layout message, not a top-level dispatcher
        # (the default config calls hl.dsp.layout("togglesplit")).
        "$mod, J, layoutmsg, togglesplit"

        # DankMaterialShell surfaces. Verbs come from the project's own
        # core/internal/config/embedded/hypr-binds.lua, translated to hyprlang.
        "$mod SHIFT, V, exec, dms ipc call clipboard toggle"
        "$mod, N, exec, dms ipc call notifications toggle"
        "$mod, X, exec, dms ipc call powermenu toggle"
        "$mod, comma, exec, dms ipc call settings focusOrToggle"
        "$mod SHIFT, Slash, exec, dms ipc call keybinds toggle hyprland"

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
      # Routed through DMS rather than brightnessctl/pamixer directly, so its
      # on-screen display appears and the shell's own state stays in step.
      binde = [
        ", XF86MonBrightnessUp, exec, dms ipc call brightness increment 5 \"\""
        ", XF86MonBrightnessDown, exec, dms ipc call brightness decrement 5 \"\""
        ", XF86AudioRaiseVolume, exec, dms ipc call audio increment 3"
        ", XF86AudioLowerVolume, exec, dms ipc call audio decrement 3"
      ];

      # Work even when the screen is locked
      bindl = [
        ", XF86AudioMute, exec, dms ipc call audio mute"
        ", XF86AudioMicMute, exec, dms ipc call audio micmute"
        ", XF86AudioPlay, exec, dms ipc call mpris playPause"
        ", XF86AudioNext, exec, dms ipc call mpris next"
        ", XF86AudioPrev, exec, dms ipc call mpris previous"

        # Clamshell mode. HandleLidSwitchDocked=ignore (modules/profiles/laptop.nix)
        # means closing the lid while docked does not suspend -- correct, since
        # you're still working on the external monitor -- but nothing was turning
        # the internal panel off or moving its workspace elsewhere, so whatever was
        # on eDP-1 was stranded behind a closed lid. Disabling a monitor makes
        # Hyprland migrate its workspace onto whatever's left active automatically.
        # When undocked, HandleLidSwitch=suspend fires separately; this just also
        # blanks the panel on the way down, which is harmless.
        ", switch:on:Lid Switch, exec, hyprctl keyword monitor eDP-1,disable"
        ", switch:off:Lid Switch, exec, hyprctl keyword monitor eDP-1,preferred,auto,auto"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # Wallpaper is DankMaterialShell's: `dms ipc call wallpaper set <path>`,
  # and enableDynamicTheming recolours the shell from it. hyprpaper removed.
}
