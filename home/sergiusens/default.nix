{ pkgs, ... }:
{
  imports = [ ./hyprland.nix ];

  home.username = "sergiusens";
  # NOTE: NixOS uses /home, not the /var/home that ostree-based Bluefin used.
  # Anything with an absolute path baked into it will need updating after the
  # migration.
  home.homeDirectory = "/home/sergiusens";
  home.stateVersion = "26.05";

  # ------------------------------------------------------------------ terminal --
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 11;
      theme = "catppuccin-mocha";

      window-padding-x = 8;
      window-padding-y = 8;
      window-decoration = false; # Hyprland draws the borders

      # Ghostty implements the Kitty graphics protocol, so inline images work —
      # worth having on a photo machine for timg, yazi previews and similar.
      confirm-close-surface = false;
      shell-integration = "bash";
      copy-on-select = "clipboard";
      mouse-hide-while-typing = true;
    };
  };

  # ----------------------------------------------------------------- launcher --
  programs.fuzzel.settings = {
    main = {
      font = "Inter:size=12";
      terminal = "${pkgs.ghostty}/bin/ghostty";
      layer = "overlay";
      width = 45;
    };
    border.radius = 8;
  };

  # ------------------------------------------------------------ notifications --
  services.mako = {
    enable = true;
    settings = {
      font = "Inter 11";
      default-timeout = 6000;
      border-radius = 8;
      padding = "12";
      anchor = "top-right";
    };
  };

  # -------------------------------------------------------------------- waybar --
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      modules-left = [
        "hyprland/workspaces"
        "hyprland/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "pulseaudio"
        "network"
        "power-profiles-daemon"
        "memory"
        "battery"
        "tray"
      ];

      clock.format = "{:%a %d %b  %H:%M}";
      battery = {
        format = "{capacity}% {icon}";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
        ];
        states = {
          warning = 25;
          critical = 10;
        };
      };
      # Worth keeping visible given the OOM history — this shows swap usage too.
      memory.format = "{percentage}%  {swapPercentage}%";
      memory.tooltip-format = "RAM {used:0.1f}G/{total:0.1f}G · swap {swapUsed:0.1f}G/{swapTotal:0.1f}G";
      network.format-wifi = "{essid} {signalStrength}%";
      pulseaudio.format = "{volume}%";
    };
  };

  # ---------------------------------------------------------------------- idle --
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true;
      background = [
        {
          blur_passes = 3;
          blur_size = 8;
        }
      ];
      input-field = [
        {
          size = "300, 50";
          position = "0, -80";
          halign = "center";
          valign = "center";
          rounding = 8;
        }
      ];
    };
  };

  # ------------------------------------------------------------------- tooling --
  programs.git = {
    enable = true;
    userName = "Sergio Enrique Schvezov";
    userEmail = "sergiusens@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  programs.bash = {
    enable = true;
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -lah";
      cat = "bat --plain";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Clipboard history daemon, fed by the Hyprland exec-once below.
  home.packages = with pkgs; [ cliphist ];

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
  };
}
