{
  nixpkgs,
  nixpkgs-stable,
  disko,
}:
{
  mkHost =
    configuration:
    let
      system = "x86_64-linux";
      pkgs-stable = import nixpkgs-stable { inherit system; };
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit pkgs-stable; };
      modules = [
        disko.nixosModules.disko
        ./common.nix
        configuration
      ];
    };
}
