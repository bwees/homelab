{
  description = "Homelab NixOS";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";
  };

  outputs =
    {
      self,
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
      nixosConfigurations.homelab-bwees = mkHost {
        system = "x86_64-linux";
        modules = [
          ./hosts/homelab-bwees/configuration.nix
        ];
      };
      nixosConfigurations.homelab-vps = mkHost {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/homelab-vps/configuration.nix
        ];
      };
    };
}
