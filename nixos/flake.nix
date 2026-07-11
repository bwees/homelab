{
  description = "Homelab NixOS";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-26.05";
    disko.url = "github:nix-community/disko";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      disko,
      ...
    }:
    let
      utils = import ./lib/utils.nix { inherit nixpkgs nixpkgs-stable; };
      inherit (utils) mkHost;
    in
    {
      nixosConfigurations.grace = mkHost {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/hail-mary/grace/configuration.nix
        ];
      };
      nixosConfigurations.rocky = mkHost {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/hail-mary/rocky/configuration.nix
        ];
      };
      nixosConfigurations.astrophage = mkHost {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/hail-mary/astrophage/configuration.nix
        ];
      };
      nixosConfigurations.tau-ceti = mkHost {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/tau-ceti/configuration.nix
        ];
      };
      nixosConfigurations.stepien = mkHost {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/stepien/configuration.nix
        ];
      };
      nixosConfigurations.eridani = mkHost {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/eridani/configuration.nix
        ];
      };
      nixosConfigurations.wolf = mkHost {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/wolf/configuration.nix
        ];
      };
    };
}
