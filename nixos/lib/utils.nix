{ nixpkgs, nixpkgs-stable }:
{
  mkHost =
    { system, modules }:
    let
      pkgs-stable = import nixpkgs-stable { inherit system; };
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit pkgs-stable; };
      inherit modules;
    };
}
