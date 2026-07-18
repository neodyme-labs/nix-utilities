{
  description = "Utility modules for NixOS and nixpkgs lib";

  inputs = {
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";

      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      nix-utils-lib = import ./lib { inherit (inputs.nixpkgs-lib) lib; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      { flake-parts-lib, ... }:
      let
        dogfood = flake-parts-lib.importApply ./flake-modules/default.nix { inherit inputs nix-utils-lib; };
      in
      {
        systems = [ "x86_64-linux" ];
        imports = [ dogfood ];

        nixUtilities.root = ./.;

        flake = {
          lib = nix-utils-lib;
        };
      }
    );
}
