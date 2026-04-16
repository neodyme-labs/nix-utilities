{ nix-utils-lib, ... }:
{ config, nixosModulePath, ... }:

let
  defaultNix = nixosModulePath + "/default.nix";
in
{
  flake = {
    nixosModule =
      if nix-utils-lib.verifyFileType "regular" defaultNix then
        nix-utils-lib.callWithIfNestedFunc 1 (import defaultNix) (
          config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
        )
      else
        {
          imports =
            map
              (
                { path, ... }:
                nix-utils-lib.callWithIfNestedFunc 1 (import path) (
                  config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
                )
              )
              (
                nix-utils-lib.readImportablePaths {
                  dir = nixosModulePath;
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
