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

    # File overlays support the extraArgs convention (README "overlays"),
    # hence the depth-2 probe.
    importFunc =
      path:
      nix-utils-lib.callWithIfNestedFuncContext (toString path) 2 (import path) (
        config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
      );

    paths = nix-utils-lib.readImportablePaths (partLib.discovery.moduleTree dir);
  };
in
{
  # The attr itself is conditional (not just its value): defining it as { }
  # would claim a flake output the layout does not actually provide.
  flake = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" walk.dir) {
    "${walk.outputName}" = walk.flakeOutputs;
  };

  partitions = lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" walk.dir) (
    lib.mapAttrs' (name: value: {
      name = "${walk.outputName}.${name}";
      inherit value;
    }) walk.partitions
  );
}
