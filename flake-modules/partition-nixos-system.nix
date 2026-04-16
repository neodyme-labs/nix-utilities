{ nix-utils-lib, ... }:
{
  config,
  inputs,
  nixosConfigurationPath,
  ...
}:

let
  metadata =
    let
      content = nix-utils-lib.callWith (import (nixosConfigurationPath + "/system-metadata.nix")) (
        config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
      );
    in
    {
      inherit (content) hostPlatform;

      nixpkgs = content.nixpkgs or inputs.nixpkgs;
      modules = content.modules or [ ];
      overlays = content.overlays or [ ];
    };

  defaultNix = nixosConfigurationPath + "/default.nix";
in
{
  flake = {
    nixosConfiguration = metadata.nixpkgs.lib.nixosSystem {
      modules = [
        {
          imports =
            if nix-utils-lib.verifyFileType "regular" defaultNix then
              [
                (nix-utils-lib.callWithIfNestedFunc 1 (import defaultNix) (
                  config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
                ))
              ]
            else
              map
                (
                  { path, ... }:
                  (nix-utils-lib.callWithIfNestedFunc 1 (import path) (
                    config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
                  ))
                )
                (
                  nix-utils-lib.readImportablePaths {
                    dir = nixosConfigurationPath;
                    excludeTopLevel = [
                      "flake.nix"
                      "flake-module.nix"
                      "system-metadata.nix"
                    ];
                    recursive = true;
                  }
                );

          config.nixpkgs = { inherit (metadata) hostPlatform overlays; };
        }
      ]
      ++ metadata.modules;
    };
  };
}
