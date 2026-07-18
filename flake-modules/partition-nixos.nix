{ flake-parts-lib, nix-utils-lib, ... }@partitionArgs:
{ config, lib, ... }:

let
  cfg = config.nixUtilities;
  partLib = import ./internal/lib.nix { inherit lib nix-utils-lib; };

  # Layout and semantics: README "nixos".
  modulesWalk = partLib.walk rec {
    inherit (config) partitions;

    dir = cfg.paths.nixosDirectory + "/modules";
    module = flake-parts-lib.importApply ./partition-nixos-module.nix partitionArgs;
    outputName = "nixosModules";
    subOutputName = "nixosModule";

    # Module files support the extraArgs convention (README "The extraArgs
    # convention"), hence the probe.
    importFunc =
      path:
      nix-utils-lib.callWithIfNestedFuncContext (toString path) 1 (import path) (
        config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
      );

    paths = nix-utils-lib.readImportablePaths (partLib.discovery.moduleTree dir);
  };

  systemsWalk = partLib.walk rec {
    inherit (config) partitions;

    dir = cfg.paths.nixosDirectory + "/systems";
    module = flake-parts-lib.importApply ./partition-nixos-system.nix partitionArgs;
    outputName = "nixosConfigurations";
    subOutputName = "nixosConfiguration";

    # systems/one/example/host -> host.example.one, so FQDN-structured
    # layouts name their configurations by FQDN.
    nameFunc =
      { path, ... }:
      lib.concatStringsSep "." (
        lib.reverseList (lib.splitString "/" (lib.removePrefix "${toString dir}/" (toString path)))
      );

    paths = nix-utils-lib.readImportablePaths (partLib.discovery.systems dir);
  };

  walks = [
    modulesWalk
    systemsWalk
  ];
in
{
  # The attrs themselves are conditional (not just their values): defining
  # them as { } would claim flake outputs the layout does not provide.
  flake =
    lib.foldr (
      walk: acc:
      acc
      // lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" walk.dir) {
        "${walk.outputName}" = walk.flakeOutputs;
      }
    ) { } walks
    // lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" systemsWalk.dir) {
      # Cheap host facts (see partition-nixos-system.nix), readable without
      # forcing a host's nixosSystem evaluation. Derived from the systems
      # walk so each host keeps a single partition; mapAttrs only forces the
      # attribute names, which preserves that laziness.
      nixosConfigurationExtras = lib.mapAttrs (
        name: _: config.partitions."nixosConfigurations.${name}".module.flake.nixosConfigurationExtra
      ) systemsWalk.flakeOutputs;
    };

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
