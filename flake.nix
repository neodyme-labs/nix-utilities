{
  description = "Utility modules for NixOS and nixpkgs lib";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";

      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";

      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      nix-utils-lib = import ./lib { inherit (inputs.nixpkgs) lib; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      { flake-parts-lib, withSystem, ... }:
      let
        inherit (flake-parts-lib) importApply;

        flakeModules.default = importApply ./flake-module.nix { inherit nix-utils-lib withSystem; };
      in
      {
        # Include required systems
        systems = [ "x86_64-linux" ];

        imports = [
          flakeModules.default
          inputs.pre-commit-hooks.flakeModule
          inputs.treefmt-nix.flakeModule
        ];

        nixUtilities = {
          root = ./.;
        };

        perSystem = {
          treefmt = {
            programs.mdformat.enable = true;

            settings.global.excludes = [
              ".idea/*"
              "*.iml"
            ];
          };
        };

        flake = rec {
          inherit flakeModules;

          lib = nix-utils-lib;
        };
      }
    );
}
