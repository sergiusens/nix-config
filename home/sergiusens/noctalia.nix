# Noctalia — the other of the two desktop shells for Hyprland, selected via
# desktop.shell (modules/desktop/shell.nix). See home/sergiusens/hyprland.nix
# for how its keybinds are picked at the same switch, and
# modules/desktop/dank.nix for the DMS side.
#
# v5, not v4: a from-scratch native C++/Wayland/OpenGL ES shell, no
# Quickshell dependency, explicitly alpha/WIP upstream as of 2026-10. All
# option names and `noctalia msg` command names below were confirmed by
# reading the actual source at the locked rev (src/cli/schema_msg.h,
# example.toml, docs/user/theming/palette.mdx) rather than assumed from
# secondhand descriptions.
{
  inputs,
  osConfig,
  lib,
  ...
}:
{
  imports = [ inputs.noctalia.homeModules.default ];

  # (osConfig.desktop or {}).shell or "dms": modules/common/home.nix applies
  # this whole profile to every host, including thufir, which never imports
  # modules/desktop/shell.nix at all -- desktop.shell does not exist there.
  config = lib.mkIf ((osConfig.desktop or { }).shell or "dms" == "noctalia") {
    programs.noctalia = {
      enable = true;
      # Starts with the graphical session, same as DMS's
      # programs.dms-shell.systemd.enable.
      systemd.enable = true;
      # Validates config.toml at build time (noctalia config validate); catches
      # a typo'd key at `nixos-rebuild switch` instead of at runtime.
      checkConfig = true;

      settings = {
        shell = {
          # Opt-in: without this, privileged prompts (Nautilus mounts, fwupd,
          # NetworkManager) have nothing to answer them. Native agent, not an
          # external hyprpolkitagent.
          polkit_agent = true;
        };

        theme = {
          mode = "light";
          source = "custom";
          custom_palette = "NordLight";
        };

        lockscreen = {
          enabled = true;
          # Default is already true upstream; declared explicitly so the
          # choice is visible in git. Holds a logind sleep-delay inhibitor and
          # locks on PrepareForSleep before suspend/hibernate, including
          # lid-close -- the same behavior set at runtime on DMS earlier
          # (lockBeforeSuspend).
          lock_before_suspend = true;
        };

        # Three-tier idle, mirroring DMS's lock -> screen-off -> suspend
        # progression. Timeouts are upstream's own shipped (but disabled by
        # default) suggestions; tune to taste once this is live.
        idle.behavior = {
          lock = {
            timeout = 600;
            action = "lock";
            enabled = true;
          };
          "screen-off" = {
            timeout = 660;
            action = "screen_off";
            enabled = true;
          };
          suspend = {
            timeout = 1800;
            action = "lock_and_suspend";
            enabled = true;
          };
        };
      };

      # Nord ships as a builtin (dark) palette, but there is no builtin light
      # variant, hence a custom one. Schema and key names (mPrimary, snake_case
      # terminal block, dark/light split) confirmed against
      # docs/user/theming/palette.mdx at the locked rev -- this is NOT the same
      # schema DMS used for its own (aborted) custom theme attempt earlier.
      #
      # Caveat confirmed against upstream issue #3714: Noctalia keeps a
      # separate runtime state file that the GUI settings/theme picker writes
      # to, which can override parts of this declarative config (wallpaper
      # specifically, per that issue). Stay out of the GUI theme/wallpaper
      # picker, or this palette will silently drift from what's in git.
      customPalettes.NordLight = {
        dark = {
          mPrimary = "#88C0D0";
          mOnPrimary = "#2E3440";
          mSecondary = "#81A1C1";
          mOnSecondary = "#2E3440";
          mTertiary = "#5E81AC";
          mOnTertiary = "#ECEFF4";
          mError = "#BF616A";
          mOnError = "#2E3440";
          mSurface = "#2E3440";
          mOnSurface = "#D8DEE9";
          mSurfaceVariant = "#3B4252";
          mOnSurfaceVariant = "#D8DEE9";
          mOutline = "#4C566A";
          mShadow = "#2E3440";
          mHover = "#434C5E";
          mOnHover = "#D8DEE9";
          terminal = {
            background = "#2E3440";
            foreground = "#D8DEE9";
            cursor = "#D8DEE9";
            cursorText = "#2E3440";
            selectionBg = "#434C5E";
            selectionFg = "#D8DEE9";
            normal = {
              black = "#3B4252";
              red = "#BF616A";
              green = "#A3BE8C";
              yellow = "#EBCB8B";
              blue = "#81A1C1";
              magenta = "#B48EAD";
              cyan = "#88C0D0";
              white = "#E5E9F0";
            };
            bright = {
              black = "#4C566A";
              red = "#BF616A";
              green = "#A3BE8C";
              yellow = "#EBCB8B";
              blue = "#81A1C1";
              magenta = "#B48EAD";
              cyan = "#8FBCBB";
              white = "#ECEFF4";
            };
          };
        };
        light = {
          mPrimary = "#5E81AC";
          mOnPrimary = "#ECEFF4";
          mSecondary = "#81A1C1";
          mOnSecondary = "#2E3440";
          mTertiary = "#88C0D0";
          mOnTertiary = "#2E3440";
          mError = "#BF616A";
          mOnError = "#ECEFF4";
          mSurface = "#ECEFF4";
          mOnSurface = "#2E3440";
          mSurfaceVariant = "#D8DEE9";
          mOnSurfaceVariant = "#434C5E";
          mOutline = "#4C566A";
          mShadow = "#D8DEE9";
          mHover = "#D8DEE9";
          mOnHover = "#2E3440";
          terminal = {
            background = "#ECEFF4";
            foreground = "#2E3440";
            cursor = "#2E3440";
            cursorText = "#ECEFF4";
            selectionBg = "#D8DEE9";
            selectionFg = "#2E3440";
            normal = {
              black = "#3B4252";
              red = "#BF616A";
              green = "#A3BE8C";
              yellow = "#EBCB8B";
              blue = "#5E81AC";
              magenta = "#B48EAD";
              cyan = "#88C0D0";
              white = "#E5E9F0";
            };
            bright = {
              black = "#4C566A";
              red = "#BF616A";
              green = "#A3BE8C";
              yellow = "#EBCB8B";
              blue = "#81A1C1";
              magenta = "#B48EAD";
              cyan = "#8FBCBB";
              white = "#ECEFF4";
            };
          };
        };
      };
    };
  };
}
