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
    in
    {
      nixosConfigurations = {
        leto = mkHost "leto" [
          nixos-hardware.nixosModules.dell-xps-13-9320
        ];

        kynes = mkHost "kynes" [
          # Provides services.kolide-launcher, which modules/work/policy.nix
          # configures. A host enabling fleet.policy must have this module.
          kolide-launcher.nixosModules.kolide-launcher
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
