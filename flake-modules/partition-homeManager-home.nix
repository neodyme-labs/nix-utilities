{ nix-utils-lib, ... }:
{ config, homePath, ... }:

let
  defaultNix = homePath + "/default.nix";
in
{
  flake = {
    home =
      if nix-utils-lib.verifyFileType "regular" defaultNix then
        nix-utils-lib.callWithIfNestedFuncContext (toString defaultNix) 1 (import defaultNix) (
          config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
        )
      else
        {
          imports =
            map
              (
                { path, ... }:
                nix-utils-lib.callWithIfNestedFuncContext (toString path) 1 (import path) (
                  config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
                )
              )
              (
                nix-utils-lib.readImportablePaths {
                  dir = homePath;
                  excludeTopLevel = [
                    "flake.nix"
                    "flake-module.nix"
                  ];
                  recursive = true;
                }
              );
        };
  };
}
