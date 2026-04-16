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
  partLib = (import ./internal/lib.nix) { inherit lib nix-utils-lib; };
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
                name = partLib.stripNixSuffix args;
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
