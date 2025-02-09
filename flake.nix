{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs?ref=nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs [
      "aarch64-linux"
      "x86_64-linux"
    ];
  in {
    packages = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        pterodactyl-wings = pkgs.callPackage ./pkgs/pterodactyl-wings.nix {};
        pelican-wings = pkgs.callPackage ./pkgs/pelican-wings.nix {};
      }
    );

    nixosModules = {
      wings = import ./modules/nixos/wings.nix self;
      panel = import ./modules/nixos/panel.nix self;
    };
  };
}
