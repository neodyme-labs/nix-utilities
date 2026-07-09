{ inputs, nix-utils-lib }:
{ config, lib, ... }:

let
  cfg = config.nixUtilities;

  managedPartitions = {
    apps = {
      attrs = [ "apps" ];
      partition = ./partition-apps.nix;
    };

    dev = {
      attrs = [
        "checks"
        "devShells"
        "formatter"
      ];

      partition = ./partition-dev.nix;
    };

    flakeModules = {
      attrs = [ "flakeModules" ];
      partition = ./partition-flakeModules.nix;
      subPath = "flake-modules";
    };

    homeManager = {
      attrs = [
        "homeConfigurations"
        "homeModules"
      ];
      partition = ./partition-homeManager.nix;
      subPath = "home-manager";
    };

    nixos = {
      attrs = [
        "nixosConfigurationExtra"
        "nixosConfigurations"
        "nixosModules"
      ];
      partition = ./partition-nixos.nix;
    };

    overlays = {
      attrs = [ "overlays" ];
      partition = ./partition-overlays.nix;
    };

    packages = {
      attrs = [ "packages" ];
      optionNamePrefix = "pkgs";
      partition = ./partition-packages.nix;
    };
  };
in
{
  # We depend on partitions and so does every consumer, so import the module
  imports = [ inputs.flake-parts.flakeModules.partitions ];

  options.nixUtilities = {
    root = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      description = "Base path used for default paths.";
    };

    # Path options are derived from the managedPartitions config
    paths = lib.mapAttrs' (
      name:
      {
        attrs,
        optionNamePrefix ? name,
        subPath ? name,
        ...
      }:
      {
        name = "${optionNamePrefix}Directory";
        value = lib.mkOption {
          type = with lib.types; nullOr path;
          default = if cfg.root != null then cfg.root + "/${subPath}" else null;
          defaultText = lib.literalMD ''
            `''${nixUtilities.root}/${subPath}`, or `null` if `nixUtilities.root` is `null`
          '';

          description = ''
            Path to the partition exposing ${lib.concatStringsSep ", " attrs}
          '';
        };
      }
    ) managedPartitions;
  };

  config =
    let
      # We only care about partitions that are actually present in the current layout
      validPartitions = lib.filterAttrs (
        name:
        {
          optionNamePrefix ? name,
          ...
        }:
        let
          path = cfg.paths."${optionNamePrefix}Directory";
        in
        path != null && nix-utils-lib.verifyFileType "directory" path
      ) managedPartitions;
    in
    {
      # Expose nix-utils-lib as an argument to all flake modules
      _module.args = { inherit nix-utils-lib; };

      partitionedAttrs = lib.listToAttrs (
        lib.flatten (
          lib.mapAttrsToList (
            partName:
            { attrs, ... }:
            map (attr: {
              name = attr;
              value = partName;
            }) attrs
          ) validPartitions
        )
      );

      partitions = lib.mapAttrs (
        name:
        {
          optionNamePrefix ? name,
          partition,
          ...
        }:
        let
          path = cfg.paths."${optionNamePrefix}Directory";

          isRegularFile = nix-utils-lib.verifyFileType "regular";
        in
        {
          module =
            if isRegularFile (path + "/flake-module.nix") then
              path + "/flake-module.nix"
            else
              nix-utils-lib.callWith (import partition) (
                config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
              );
        }
        // lib.optionalAttrs (isRegularFile (path + "/flake.nix") && isRegularFile (path + "/flake.lock")) {
          extraInputsFlake = path;
        }
      ) validPartitions;
    };
}
