{ nix-utils-lib, ... }:
{
  config,
  inputs,
  lib,
  self,
  ...
}:

let
  cfg = config.nixUtilities;
  partLib = import ./internal/lib.nix { inherit lib nix-utils-lib; };
in
{
  perSystem =
    { config, pkgs, ... }:
    let
      importDir =
        dir:
        lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" dir) (
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
    in
    {
      checks = importDir (cfg.paths.devDirectory + "/checks");
      devShells = importDir (cfg.paths.devDirectory + "/shells");

      # One step weaker than mkDefault (1000), so treefmt-nix and the like
      # can take over the formatter without friction
      formatter = lib.mkOverride 1001 (
        let
          path = cfg.paths.devDirectory + "/formatter.nix";
        in
        if nix-utils-lib.verifyFileType "regular" path then
          # callPackageWith intersects the extra arguments with the function's
          # parameters; passing them as callPackage's explicit args would force
          # them all onto a formatter.nix lacking `...`. pkgs is merged last:
          # allModuleArgs carries the perSystem `config` (and module-system
          # `lib`), which would shadow the nixpkgs meaning nixpkgs-style files
          # expect (`config.allowUnfree`, `pkgs.lib`).
          lib.callPackageWith (
            config.allModuleArgs // { inherit inputs nix-utils-lib self; } // pkgs
          ) (import path) { }
        else
          null
      );
    };
}
