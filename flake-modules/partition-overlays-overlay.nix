{ nix-utils-lib, ... }:
{
  config,
  lib,
  overlayPath,
  ...
}:

let
  defaultNix = overlayPath + "/default.nix";
in
{
  flake = {
    overlay =
      if nix-utils-lib.verifyFileType "regular" defaultNix then
        nix-utils-lib.callWithIfNestedFunc 2 (import defaultNix) (
          config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
        )
      else
        final: prev:
        lib.listToAttrs (
          map
            (
              { path, ... }@args:
              {
                name = nix-utils-lib.stripNixSuffix args;

                value =
                  (nix-utils-lib.callWithIfNestedFunc 2 (import path) (
                    config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
                  ))
                    final
                    prev;
              }
            )
            (
              nix-utils-lib.readImportablePaths {
                dir = overlayPath;
                exclude = [
                  "flake.nix"
                  "flake-module.nix"
                ];
              }
            )
        );
  };
}
