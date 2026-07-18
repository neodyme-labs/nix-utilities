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
        nix-utils-lib.callWithIfNestedFuncContext (toString defaultNix) 2 (import defaultNix) (
          config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
        )
      else
        # Every part is an ordinary overlay returning an attribute set; they
        # are composed in discovery (alphabetical) order, later parts seeing
        # earlier ones through `prev`.
        lib.composeManyExtensions (
          map
            (
              { path, ... }:
              nix-utils-lib.callWithIfNestedFuncContext (toString path) 2 (import path) (
                config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
              )
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
