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
  partLib = import ./internal/lib.nix { inherit lib nix-utils-lib; };
in
{
  perSystem = { config, ... }: {
    apps = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" dir) (
      nix-utils-lib.uniqueListToAttrs (
        map (
          { path, ... }@args:
          {
            inherit path;
            name = nix-utils-lib.stripNixSuffix args;
            value = nix-utils-lib.callWithContext (toString path) (import path) (
              config.allModuleArgs // { inherit inputs nix-utils-lib self; }
            );
          }
        ) (nix-utils-lib.readImportablePaths (partLib.discovery.entries dir))
      )
    );
  };
}
