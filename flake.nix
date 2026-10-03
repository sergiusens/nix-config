{
  description = "Atreides fleet — NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Escape hatch for packages that must track the bleeding edge, exposed as
    # pkgs.unstable.<name> by the overlay below. Use sparingly.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Per-model hardware quirks. leto is a dell-xps-13-9320.
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative partitioning. Inert during nixos-rebuild; only the explicit
    # disko commands touch a disk. See hosts/leto/disko.nix.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kolide's own packaging of their launcher, providing both the package and a
    # NixOS module. Deliberately NOT following our nixpkgs: they pin and test
    # against their own (currently nixos-26.05, the same release), and for a
    # compliance agent their tested combination is worth more than deduplicating
    # one nixpkgs eval.
    kolide-launcher.url = "github:kolide/nix-agent/main";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixos-hardware,
      home-manager,
      disko,
      sops-nix,
      kolide-launcher,
      ...
    }:
    let
      system = "x86_64-linux";

      unstableOverlay = _final: _prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      # hostName is threaded through specialArgs so modules/common can set
      # networking.hostName without each host repeating itself.
      mkHost =
        hostName: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs hostName; };
          modules = [
            { nixpkgs.overlays = [ unstableOverlay ]; }
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./modules/common
            ./hosts/${hostName}
          ]
          ++ extraModules;
        };

      # nixos-hardware has NO dell-xps-13-9320 module — the XPS 13 family there
      # stops at 9315/9310/9350, and guessing a neighbouring model would apply
      # quirks for different hardware. Compose the generic profiles instead:
      #   common-cpu-intel      microcode, and imports common-gpu-intel, which
      #                         drives hardware.intelgpu (see
      #                         modules/hardware/intel-graphics.nix)
      #   common-pc-laptop      only enables TLP when power-profiles-daemon is
      #                         off, so it does not fight modules/profiles/laptop.nix
      #   common-pc-laptop-ssd  SSD-appropriate defaults
      laptopProfiles = [
        nixos-hardware.nixosModules.common-cpu-intel
        nixos-hardware.nixosModules.common-pc-laptop
        nixos-hardware.nixosModules.common-pc-laptop-ssd
      ];
    in
    {
      nixosConfigurations = {
        leto = mkHost "leto" laptopProfiles;

        kynes = mkHost "kynes" (
          laptopProfiles
          ++ [
            # Provides services.kolide-launcher, which modules/work/policy.nix
            # configures. A host enabling fleet.policy must have this module.
            kolide-launcher.nixosModules.kolide-launcher
          ]
        );
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
