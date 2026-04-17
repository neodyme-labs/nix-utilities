{ nix-utils-lib, ... }:
{
  config,
  inputs,
  lib,
  self,
  ...
}:

let
  dir = config.nixUtilities.paths.pkgsDirectory;
in
{
  perSystem =
    { config, pkgs, ... }:
    {
      packages = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" dir) (
        builtins.listToAttrs (
          map
            (
              { path, ... }@args:
              {
                name = nix-utils-lib.stripNixSuffix args;
                value = pkgs.callPackage (import path) (
                  config.allModuleArgs // { inherit inputs nix-utils-lib self; }
                );
              }
            )
            (
              nix-utils-lib.readImportablePaths {
                inherit dir;

                exclude = [
                  "flake.nix"
                  "flake-module.nix"
                ];
              }
            )
        )
      );
    };
}
