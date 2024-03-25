{
  description = "nix-utilities example";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-utilities = {
      url = "git+ssh://git@gitlab.com/neodyme-labs/infrastructure/nix-utilities.git";

      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
        pre-commit-hooks.follows = "pre-commit-hooks";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

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
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Include required systems
      systems = [ "x86_64-linux" ];

      imports = [
        inputs.nix-utilities.flakeModules.default
        inputs.pre-commit-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      nixUtilities = {
        root = ./.;
      };
    };
}
