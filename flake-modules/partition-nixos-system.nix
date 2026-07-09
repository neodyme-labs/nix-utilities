{ nix-utils-lib, ... }:
{
  config,
  inputs,
  nixosConfigurationName,
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

  # This host's own fully-resolved inputs (root inputs merged with this system's
  # own extraInputsFlake, if any). Exposed to modules as a NixOS specialArg named
  # `hostInputs`, distinct from a module's own eagerly-resolved `inputs`, so a
  # shared module can be written to prefer a host's override while still falling
  # back to whatever it itself (or the root flake) already defines, e.g.:
  #   { inputs, ... }: { config, lib, hostInputs, ... }:
  #   let effectiveInputs = inputs // hostInputs; in { ... }
  hostInputs = inputs;
in
{
  flake = {
    nixosConfiguration = metadata.nixpkgs.lib.nixosSystem {
      specialArgs = { inherit hostInputs; };

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

          config = {
            nixpkgs = { inherit (metadata) hostPlatform overlays; };

            _module.args = { inherit nixosConfigurationName nixosConfigurationPath; };
          };
        }
      ]
      ++ metadata.modules;
    };
  };
}
