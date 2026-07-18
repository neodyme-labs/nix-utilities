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
  partLib = import ./internal/lib.nix { inherit lib nix-utils-lib; };
in
{
  perSystem = { config, pkgs, ... }: {
    packages = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" dir) (
      nix-utils-lib.uniqueListToAttrs (
        map (
          { path, ... }@args:
          {
            inherit path;
            name = nix-utils-lib.stripNixSuffix args;
            # callPackageWith intersects the extra arguments with the
            # function's parameters; passing them as callPackage's explicit
            # args would force them all onto files lacking `...`. pkgs is
            # merged last: allModuleArgs carries the perSystem `config` (and
            # module-system `lib`), which would shadow the nixpkgs meaning
            # nixpkgs-style files expect (`config.allowUnfree`, `pkgs.lib`).
            value = lib.callPackageWith (
              config.allModuleArgs // { inherit inputs nix-utils-lib self; } // pkgs
            ) (import path) { };
          }
        ) (nix-utils-lib.readImportablePaths (partLib.discovery.entries dir))
      )
    );
  };
}
