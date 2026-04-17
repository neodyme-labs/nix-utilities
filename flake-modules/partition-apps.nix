{ nix-utils-lib, ... }:
{
  config,
  inputs,
  lib,
  self,
  ...
}:

let
  dir = config.nixUtilities.paths.appsDirectory;
  partLib = (import ./internal/lib.nix) { inherit lib nix-utils-lib; };
in
{
  perSystem =
    { config, ... }:
    {
      apps = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" dir) (
        builtins.listToAttrs (
          map
            (
              { path, ... }@args:
              {
                name = nix-utils-lib.stripNixSuffix args;
                value = nix-utils-lib.callWith (import path) (
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
