{ nix-utils-lib, ... }:
{ config, lib, ... }:

let
  dir = config.nixUtilities.paths.flakeModulesDirectory;
  partLib = import ./internal/lib.nix { inherit lib nix-utils-lib; };
in
{
  flake = {
    flakeModules = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" dir) (
      nix-utils-lib.uniqueListToAttrs (
        map (
          { path, ... }@args:
          {
            inherit path;
            name = nix-utils-lib.stripNixSuffix args;

            # The following kind of modules are supported:
            # extraArgs: args: { ... }
            # args: { ... }
            # { ... }
            value = nix-utils-lib.callWithIfNestedFuncContext (toString path) 1 (import path) (
              config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
            );
          }
        ) (nix-utils-lib.readImportablePaths (partLib.discovery.entries dir))
      )
    );
  };
}
