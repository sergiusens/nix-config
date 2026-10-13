{
  pkgs,
  hostName,
  osConfig,
  ...
}:
let
  # "dms" | "noctalia" -- modules/desktop/shell.nix. Defaults to "dms" on
  # hosts that never import that module (thufir: modules/common/home.nix
  # applies this whole profile everywhere, headless or not).
  shell = (osConfig.desktop or { }).shell or "dms";
in
{
  imports = [
    ./hyprland.nix
    ./herdr.nix
    ./hyprdynamicmonitors.nix
    ./noctalia.nix
  ];

  # Déjà Dup is installed (modules/profiles/desktop-apps.nix) but deliberately
  # NOT configured declaratively. The existing repository is unencrypted
  # (restic with --insecure-no-password), so the plan is: restore from it by
  # hand after the reinstall, then create a fresh ENCRYPTED repository and
  # retire the old one. Encoding the old settings here would only make it easy
  # to recreate the thing being replaced.
  #
  # The new repository should also target a share named `leto` rather than
  # `cuivienen`, which still carries the pre-rename hostname.
  # See INSTALL.md for the restore procedure.

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
      # Ghostty's bundled theme names are the upstream iTerm2-Color-Schemes
      # names: capitalised, spaced. A typo'd/nonexistent name (`catppuccin-mocha`
      # does not exist, for instance) opens a "Configuration Errors" dialog on
      # every start. Full list:
      #   ls $(nix eval --raw .#…pkgs.ghostty)/share/ghostty/themes
      # "Nord" and "Nord Light" are both bundled -- confirmed in that listing.
      # `light:X,dark:Y` is Ghostty's own native syntax: it follows the
      # desktop's actual light/dark signal, which tracks reality (including a
      # dark/light toggle inside Noctalia itself) better than keying off
      # desktop.shell directly would.
      theme = "light:Nord Light,dark:Nord";

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

  # Launcher, notifications, bar, idle and lock all come from
  # DankMaterialShell now (modules/desktop/dank.nix). The fuzzel, mako,
  # waybar, hypridle and hyprlock blocks that used to live here were removed
  # rather than left to run in parallel with DMS's own.

  # ------------------------------------------------------------------- tooling --
  # home-manager renamed userName/userEmail/extraConfig into a single freeform
  # `settings` attrset that mirrors git config structure directly.
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Sergio Schvezov";
        email = "sergio@schvezov.net";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;

      # Mirrors what `gh auth setup-git` writes to ~/.gitconfig: clear the
      # empty default helper first, then point at gh so HTTPS pushes don't
      # prompt. Previously lived in a hand-edited ~/.gitconfig, which is how
      # it silently reverted to a dead /home/linuxbrew path after a backup
      # restore overwrote it — declaring it here means a restore can't touch it.
      credential."https://github.com".helper = [
        ""
        "!${pkgs.gh}/bin/gh auth git-credential"
      ];
      credential."https://gist.github.com".helper = [
        ""
        "!${pkgs.gh}/bin/gh auth git-credential"
      ];
    };
  };

  # -------------------------------------------------------------------- prompt --
  # Integration is injected into programs.bash below automatically; no manual
  # eval line needed.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;

      # THE one that matters with a fleet this size. ssh_only means the
      # hostname is invisible locally and appears the moment you are on
      # another machine — so there is never any doubt whether a command is
      # about to run on leto or on thufir.
      hostname = {
        ssh_only = true;
        format = "[$hostname](bold red) ";
      };
      # Likewise only shown when it is not you.
      username = {
        show_always = false;
        format = "[$user](bold yellow)@";
      };

      directory = {
        truncation_length = 4;
        truncate_to_repo = true;
      };

      git_branch.symbol = " ";
      git_status.disabled = false;

      # Visible marker that the shell is inside a nix develop / nix-shell,
      # which matters constantly in this repo and in ../gthumb.
      nix_shell = {
        disabled = false;
        format = "via [$symbol$state]($style) ";
        symbol = "❄️ ";
      };

      # Only flag commands slow enough to be worth noticing.
      cmd_duration = {
        min_time = 2000;
        format = "took [$duration](yellow) ";
      };

      # Red prompt character after a failed command.
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
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
  home.packages = with pkgs; [
    cliphist
    tig
    # Needed by the simple-english Claude Code plugin's lint hook
    # (~/.claude/plugins/.../src/hooks/lint_hook.py), run on every Write/Edit
    # and on Stop. Without this, both hooks fail with "python3: command not
    # found".
    python3
  ];

  # Default browser differs by host: leto is Firefox, kynes keeps the
  # work-issued Chrome. Hyprland has no desktop environment to arbitrate this,
  # so the associations have to be stated.
  xdg.mimeApps =
    let
      browser = if hostName == "kynes" then "google-chrome.desktop" else "firefox.desktop";
    in
    {
      enable = true;
      defaultApplications = {
        "text/html" = browser;
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/about" = browser;
        "x-scheme-handler/unknown" = browser;
        "application/pdf" = "org.gnome.Papers.desktop";
        "image/jpeg" = "org.gnome.gthumb.desktop";
        "image/png" = "org.gnome.gthumb.desktop";
      };
    };

  home.sessionVariables.BROWSER =
    if hostName == "kynes" then "google-chrome-stable" else "firefox";

  # Real Nord-palette packages, not generic Adwaita: pkgs.nordic is
  # EliverLara's Nordic (GTK + KDE themes built on the actual Nord colors),
  # and pkgs.papirus-nord is Papirus with its folder icons recolored to a
  # Nord accent (defaults to frostblue1, which is the same Frost blue used
  # as the primary accent everywhere else in this Nord setup).
  #
  # There is no genuine light Nordic variant upstream -- "Nordic" itself is
  # explicitly a dark GTK3.20+ theme. Nordic-Polar is the closest real thing:
  # EliverLara's own description calls it "a mixed theme using light
  # widgets," i.e. still fundamentally dark, not a true light surface theme.
  # It is what Noctalia's light side gets regardless, since it is the only
  # Nord-palette GTK option that leans light at all; DMS keeps the standard
  # dark Nordic-bluish-accent variant, matching papirus-nord's blue accent.
  # Both revert along with everything else when desktop.shell flips back.
  #
  # GTK3's gtk-theme-name (below) only reaches GTK3 apps. GTK4/libadwaita
  # apps (Nautilus, Papers, GNOME Secrets) ignore classic theme CSS entirely
  # and instead render their own light/dark adaptive stylesheet based on the
  # org.freedesktop.appearance "color-scheme" portal value -- backed by this
  # dconf key, which xdg-desktop-portal-gtk reads to answer that portal
  # query. Confirmed live: color-scheme stayed at 1 (prefer-dark) under
  # Noctalia with only gtk.theme set, because nothing was writing this key.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if shell == "noctalia" then "prefer-light" else "prefer-dark";

  gtk = {
    enable = true;
    theme =
      if shell == "noctalia" then
        {
          name = "Nordic-Polar";
          package = pkgs.nordic;
        }
      else
        {
          name = "Nordic-bluish-accent";
          package = pkgs.nordic;
        };
    iconTheme =
      if shell == "noctalia" then
        {
          name = "Papirus-Light";
          package = pkgs.papirus-nord;
        }
      else
        {
          name = "Papirus-Dark";
          package = pkgs.papirus-nord;
        };
  };

  # GTK3 apps (Firefox included -- it's GTK3 on Linux, not GTK4) read this
  # straight from settings.ini, independent of both the theme name above and
  # the dconf/portal color-scheme key: nothing else was setting it, which is
  # why Firefox stayed dark under Noctalia even on its "System" theme
  # setting -- it was reading the system as dark because this was unset.
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = shell != "noctalia";

  home.pointerCursor = {
    gtk.enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
  };
}
