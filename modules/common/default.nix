# Baseline shared by every NixOS host in the fleet.
{
  lib,
  pkgs,
  hostName,
  ...
}:
{
  imports = [ ./home.nix ];

  # ---------------------------------------------------------------- identity --
  networking.hostName = hostName;
  networking.domain = "atreides";
  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------- nix --
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
      # Keep build logs and failed-build dirs useful when iterating.
      keep-outputs = true;
      keep-derivations = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise.automatic = true;
  };

  nixpkgs.config.allowUnfree = true;

  # --------------------------------------------------------------------- boot --
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        # Bound the ESP; each generation's kernel+initrd is ~100 MB.
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
    # systemd in initrd: needed for a clean LUKS passphrase prompt and plymouth.
    initrd.systemd.enable = true;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # Two-tier swap, fast tier. zram is compressed RAM, so it does NOT add
  # capacity — it trades CPU for a better bytes-per-page ratio and competes with
  # applications for the same 30 GiB. Kept deliberately small; the real overflow
  # capacity is a disk swapfile declared per-host (see hosts/leto/disko.nix).
  #
  # NixOS gives zram priority 5 and disk swap priority -2 by default, so the
  # kernel fills the fast tier first and only spills to disk under real pressure.
  zramSwap = {
    enable = true;
    algorithm = "zstd"; # lzo-rle on the Bluefin images; zstd compresses better
    memoryPercent = 25;
  };

  boot.kernel.sysctl = {
    # Bluefin shipped vm.swappiness=10, which all but forbids swapping. That is
    # reasonable when swap is slow spinning rust; it is wrong here, where the
    # first tier is compressed RAM and the second is NVMe. A low value is what
    # leaves memory-hungry applications with nowhere to spill.
    "vm.swappiness" = 100;

    # Reclaim inodes/dentries a little more readily than the default 100 — these
    # machines hold hundreds of thousands of image files and the dentry cache
    # grows without bound otherwise.
    "vm.vfs_cache_pressure" = 150;
  };

  # ------------------------------------------------------------------- locale --
  time.timeZone = "America/Argentina/Cordoba";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "es_AR.UTF-8/UTF-8"
      "C.UTF-8/UTF-8"
    ];
  };

  # Latin American layout, matching the hardware. Note that Hyprland does NOT
  # read services.xserver.xkb — the compositor's own input.kb_layout in
  # home/sergiusens/hyprland.nix is what governs a Wayland session. This setting
  # covers XWayland clients and the greeter.
  console.keyMap = "la-latin1";
  services.xserver.xkb.layout = "latam";

  # -------------------------------------------------------------------- users --
  users.users.sergiusens = {
    isNormalUser = true;
    description = "Sergio Enrique Schvezov";
    uid = 1000;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "dialout" # serial devices, carried over from the Bluefin group set
      "lp"
      "scanner"
      "podman"
    ];
    shell = pkgs.bash;

    # TODO: add your SSH public keys here before relying on remote deploys.
    # Deliberately left empty rather than copied out of bluefin-xp's orthanc.bu,
    # since those are the server's authorized keys and it is not clear which
    # still correspond to live private keys.
    openssh.authorizedKeys.keys = [ ];
  };

  security.sudo.wheelNeedsPassword = true;

  # ----------------------------------------------------------------------- ssh --
  # Needed for `nixos-rebuild --target-host` and deploy-rs. Key-only.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
  };

  networking.firewall.enable = true;

  # --------------------------------------------------------------------- audio --
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ---------------------------------------------------------------- containers --
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # --------------------------------------------------------------------- fonts --
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      inter
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Inter" ];
      monospace = [ "JetBrainsMono Nerd Font" ];
    };
  };

  # ------------------------------------------------------------------ packages --
  environment.systemPackages = with pkgs; [
    bat
    btop
    curl
    fd
    file
    gh
    git
    jq
    just
    neovim
    pciutils
    ripgrep
    tree
    unzip
    usbutils
    wget
  ];

  programs.direnv.enable = true;

  # Flatpak kept as an escape hatch for apps not worth packaging. The Bluefin
  # images preinstalled localsend and the Nextcloud client; both are in nixpkgs
  # and are installed natively per-host instead.
  services.flatpak.enable = true;

  # Needed by Nextcloud client, Chrome and anything else storing secrets.
  services.gnome.gnome-keyring.enable = true;

  # Set once and not bumped — this pins stateful-data migration behaviour, it is
  # not a "which nixpkgs" knob. Leave it alone unless you read the release notes.
  system.stateVersion = "26.05";
}
