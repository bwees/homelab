{
  description = "Homelab NixOS";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    {
      nixosConfigurations.homelab-bwees = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/homelab-bwees/configuration.nix
        ];
      };
    };
}
