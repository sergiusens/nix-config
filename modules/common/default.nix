# Baseline shared by every NixOS host in the fleet.
{
  config,
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

    # Deliberately NOT linuxPackages_latest. Both hosts depend on out-of-tree or
    # kernel-version-sensitive modules that lag the newest kernel:
    #   - leto needs ipu6-drivers (out-of-tree) for the camera's hardware ISP;
    #     an out-of-tree module that fails to build takes the whole rebuild with
    #     it, and "my camera broke after an update" is the usual symptom.
    #   - kynes runs the Falcon sensor, which drops into Reduced Functionality
    #     Mode when the kernel outruns what CrowdStrike supports.
    # The NixOS default is the well-tested choice that out-of-tree packages are
    # maintained against. Pin a specific kernel per-host if you need one.
    kernelPackages = pkgs.linuxPackages;
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

    # NO PASSWORD IS SET HERE, deliberately. Options, worst to best:
    #   initialPassword      — plaintext, world-readable in the nix store
    #   initialHashedPassword— hash in git; fine for a bootstrap, still public
    #   hashedPasswordFile   — a sops-nix secret; the right long-term answer
    #
    # Until one of those exists the account has no password and cannot log in at
    # the greeter. The install procedure in INSTALL.md covers this: nixos-install
    # prompts for a root password, and `passwd sergiusens` from a root TTY sets
    # yours. mutableUsers stays true below so that works.
  };

  # Passwords can be changed with passwd and survive a rebuild. Set false only
  # once hashedPasswordFile is wired to sops, or a rebuild will lock you out.
  users.mutableUsers = true;

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

  # ----------------------------------------------------------------- tailnet --
  # Every host joins the tailnet (great-torino.ts.net). It is how machines reach
  # each other away from the LAN — the Deja Dup target is already an SMB URI on
  # the tailnet rather than a 192.168 address — and it is what makes remote
  # administration of a roaming laptop possible at all.
  services.tailscale = {
    enable = true;
    # "client" accepts subnet routes advertised by other nodes without
    # advertising any itself. thufir is the one that exports the LAN.
    useRoutingFeatures = "client";
  };

  # Traffic arriving over the tailnet is trusted: it is already authenticated
  # and encrypted by WireGuard, and these are all machines in this fleet.
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    # Lets tailscaled negotiate direct connections instead of relaying via DERP.
    allowedUDPPorts = [ config.services.tailscale.port ];
    # Required for direct connections to survive the firewall seeing the
    # WireGuard handshake on an unexpected interface.
    checkReversePath = "loose";
  };

  # NOTE: enabling the daemon does not enrol the machine. Each host still needs
  # a one-off `sudo tailscale up` — or an auth key via
  # services.tailscale.authKeyFile pointed at a sops secret, which is the right
  # answer once secrets exist and is what unattended provisioning will need.

  # ---------------------------------------------------------------- containers --
  # In common rather than the desktop profile: thufir's entire job is running
  # containers, and podman is useful on a workstation too.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # ------------------------------------------------------------------ packages --
  # The CLI baseline every host gets, headless included.
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

  # Audio, fonts, flatpak and the login keyring live in
  # modules/profiles/desktop.nix — a headless server wants none of them.

  # Set once and not bumped — this pins stateful-data migration behaviour, it is
  # not a "which nixpkgs" knob. Leave it alone unless you read the release notes.
  system.stateVersion = "26.05";
}
