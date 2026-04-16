{ flake-parts-lib, nix-utils-lib, ... }@partitionArgs:
{ config, lib, ... }:

let
  partLib = (import ./internal/lib.nix) { inherit lib nix-utils-lib; };

  walk = partLib.walk rec {
    inherit (config) partitions;

    dir = config.nixUtilities.paths.overlaysDirectory;
    module = flake-parts-lib.importApply ./partition-overlays-overlay.nix partitionArgs;
    outputName = "overlays";
    subOutputName = "overlay";

    # The following kind of overlays are supported:
    # extraArgs: final: prev: { }
    # final: prev: { }
    importFunc =
      path:
      nix-utils-lib.callWithIfNestedFunc 2 (import path) (
        config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
      );

    paths = nix-utils-lib.readImportablePaths {
      inherit dir;
      dirIncludibilityCheck = _: true; # All directories are allowed

      exclude = [
        "flake.nix"
        "flake-module.nix"
      ];
    };
  };
in
{
  flake."${walk.outputName}" =
    lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" walk.dir) walk.flakeOutputs;

  partitions = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" walk.dir) (
    lib.mapAttrs' (name: value: {
      name = "${walk.outputName}.${name}";
      inherit value;
    }) walk.partitions
  );
}
