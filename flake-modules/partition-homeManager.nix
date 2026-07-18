{ flake-parts-lib, nix-utils-lib, ... }@partitionArgs:
{ config, lib, ... }:

let
  cfg = config.nixUtilities;
  partLib = import ./internal/lib.nix { inherit lib nix-utils-lib; };

  # Layout and semantics: README "homeManager". homes/ is deliberately its
  # own directory - user homes and shared modules diverge in multi-user
  # setups - and home-configurations/ is decoupled from both, so a home
  # stays host-embeddable (osConfig, per-host pkgs) while standalone
  # builds are opt-in per configuration.
  # Module and home files support the extraArgs convention (README "The
  # extraArgs convention"), hence the probe.
  extraArgsImportFunc =
    path:
    nix-utils-lib.callWithIfNestedFuncContext (toString path) 1 (import path) (
      config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
    );

  modulesWalk = partLib.walk rec {
    inherit (config) partitions;

    dir = cfg.paths.homeManagerDirectory + "/modules";
    module = flake-parts-lib.importApply ./partition-homeManager-module.nix partitionArgs;
    outputName = "homeModules";
    subOutputName = "homeModule";

    importFunc = extraArgsImportFunc;
    paths = nix-utils-lib.readImportablePaths (partLib.discovery.moduleTree dir);
  };

  homesWalk = partLib.walk rec {
    inherit (config) partitions;

    dir = cfg.paths.homeManagerDirectory + "/homes";
    module = flake-parts-lib.importApply ./partition-homeManager-home.nix partitionArgs;
    outputName = "homes";
    subOutputName = "home";

    importFunc = extraArgsImportFunc;
    paths = nix-utils-lib.readImportablePaths (partLib.discovery.moduleTree dir);
  };

  configurationsWalk = partLib.walk rec {
    inherit (config) partitions;

    dir = cfg.paths.homeManagerDirectory + "/home-configurations";
    module = flake-parts-lib.importApply ./partition-homeManager-configuration.nix partitionArgs;
    outputName = "homeConfigurations";
    subOutputName = "homeConfiguration";

    paths = nix-utils-lib.readImportablePaths (partLib.discovery.homeConfigurations dir);
  };

  walks = [
    modulesWalk
    homesWalk
    configurationsWalk
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
    // lib.optionalAttrs (nix-utils-lib.verifyFileType "directory" configurationsWalk.dir) {
      # Cheap per-home facts, readable without forcing a home's build -
      # mirrors flake.nixosConfigurationExtras (see partition-nixos.nix).
      homeConfigurationExtras = lib.mapAttrs (
        name: _: config.partitions."homeConfigurations.${name}".module.flake.homeConfigurationExtra
      ) configurationsWalk.flakeOutputs;
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
