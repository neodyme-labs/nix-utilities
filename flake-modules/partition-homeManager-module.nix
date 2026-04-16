{ nix-utils-lib, ... }:
{ config, homeModulePath, ... }:

let
  defaultNix = homeModulePath + "/default.nix";
in
{
  flake = {
    homeModule =
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
                  dir = homeModulePath;
                  exclude = [
                    "flake.nix"
                    "flake-module.nix"
                  ];
                }
              );
        };
  };
}
