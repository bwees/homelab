{
  description = "Homelab NixOS";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      disko,
      ...
    }:
    let
      utils = import ./lib/utils.nix { inherit nixpkgs nixpkgs-stable disko; };
    in
    {
      nixosConfigurations = builtins.mapAttrs (_: utils.mkHost) {
        grace = ./hosts/hail-mary/grace/configuration.nix;
        rocky = ./hosts/hail-mary/rocky/configuration.nix;
        astrophage = ./hosts/hail-mary/astrophage/configuration.nix;
        xenonite = ./hosts/hail-mary/xenonite/configuration.nix;
        stepien = ./hosts/stepien/configuration.nix;
        eridani = ./hosts/eridani/configuration.nix;
      };
    };
}
