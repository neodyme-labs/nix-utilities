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
in
{
  perSystem =
    { config, pkgs, ... }:
    let
      importDir =
        dir:
        lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" dir) (
          builtins.listToAttrs (
            map (
              { path, ... }@args:
              {
                name = nix-utils-lib.stripNixSuffix args;
                value = nix-utils-lib.callWith (import path) (
                  config.allModuleArgs // { inherit inputs nix-utils-lib self; }
                );
              }
            ) (nix-utils-lib.readImportablePaths { inherit dir; })
          )
        );
    in
    {
      checks = importDir (cfg.paths.devDirectory + "/checks");
      devShells = importDir (cfg.paths.devDirectory + "/shells");

      # Priority 1001 is 1 less than mkDefault (used by treefmt-nix and the like)
      formatter = lib.mkOverride 1001 (
        let
          path = cfg.paths.devDirectory + "/formatter.nix";
        in
        if nix-utils-lib.verifyFileType "regular" path then
          pkgs.callPackage (import path) (config.allModuleArgs // { inherit inputs nix-utils-lib self; })
        else
          null
      );
    };
}
