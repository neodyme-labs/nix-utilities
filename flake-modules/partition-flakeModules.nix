{ nix-utils-lib, ... }:
{ config, lib, ... }:

let
  dir = config.nixUtilities.paths.flakeModulesDirectory;
  partLib = (import ./internal/lib.nix) { inherit lib nix-utils-lib; };
in
{
  flake = {
    flakeModules = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" dir) (
      builtins.listToAttrs (
        map
          (
            { path, ... }@args:
            {
              name = nix-utils-lib.stripNixSuffix args;

              # The following kind of modules are supported:
              # extraArgs: args: { ... }
              # args: { ... }
              # { ... }
              value = nix-utils-lib.callWithIfNestedFunc 1 (import path) (
                config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
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
