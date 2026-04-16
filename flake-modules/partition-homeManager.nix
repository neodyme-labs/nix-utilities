{ flake-parts-lib, nix-utils-lib, ... }@partitionArgs:
{ config, lib, ... }:

let
  cfg = config.nixUtilities;
  partLib = (import ./internal/lib.nix) { inherit lib nix-utils-lib; };

  walks = [
    # The following modules structure is supported:
    #   modules/
    #   +-- <name>.nix            - Included as module
    #   +-- <name>/               - Sub-partition for a module
    #       +-- default.nix       - Our implementation: included if present, recursively includes all other nix files, or includible directories otherwise
    #       +-- flake.{nix,lock}  - Additional inputs for the sub-partition
    #       +-- flake-module.nix  - Overrides our implementation if present
    (partLib.walk rec {
      inherit (config) partitions;

      dir = cfg.paths.homeManagerDirectory + "/modules";
      module = flake-parts-lib.importApply ./partition-homeManager-module.nix partitionArgs;
      outputName = "homeModules";
      subOutputName = "homeModule";

      # The following kind of modules are supported:
      # extraArgs: args: { }
      # args: { }
      # { }
      importFunc =
        path:
        nix-utils-lib.callWithIfNestedFunc 1 (import path) (
          config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
        );

      paths = nix-utils-lib.readImportablePaths {
        inherit dir;
        dirIncludibilityCheck = _: true; # All directories are allowed
      };
    })

    # The following home structure is supported:
    #   homes/
    #   +-- <name>.nix            - Included as home
    #   +-- <name>/               - Sub-partition for a home
    #       +-- default.nix       - Our implementation: included if present, recursively includes all other nix files, or includible directories otherwise
    #       +-- flake.{nix,lock}  - Additional inputs for the sub-partition
    #       +-- flake-module.nix  - Overrides our implementation if present
    (partLib.walk rec {
      inherit (config) partitions;

      dir = cfg.paths.homeManagerDirectory + "/homes";
      module = flake-parts-lib.importApply ./partition-homeManager-home.nix partitionArgs;
      outputName = "homeConfigurations";
      subOutputName = "homeConfiguration";

      # The following kind of homes are supported:
      # extraArgs: args: { }
      # args: { }
      # { }
      importFunc =
        path:
        nix-utils-lib.callWithIfNestedFunc 1 (import path) (
          config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
        );

      paths = nix-utils-lib.readImportablePaths {
        inherit dir;
        dirIncludibilityCheck = _: true; # All directories are allowed
      };
    })
  ];
in
{
  flake = lib.foldr (
    walk: acc:
    acc
    // {
      "${walk.outputName}" =
        lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" walk.dir) walk.flakeOutputs;
    }
  ) { } walks;

  partitions = lib.foldr (
    walk: acc:
    acc
    // lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" walk.dir) (
      lib.mapAttrs' (name: value: {
        name = "${walk.outputName}.${name}";
        inherit value;
      }) walk.partitions
    )
  ) { } walks;
}
