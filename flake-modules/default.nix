{ inputs, nix-utils-lib }:
{ config, lib, ... }:

let
  cfg = config.nixUtilities;
  partLib = import ./internal/lib.nix { inherit lib nix-utils-lib; };

  moduleTreeHasEntries = partLib.hasEntries partLib.discovery.moduleTree;
  entriesHasEntries = partLib.hasEntries partLib.discovery.entries;

  # Each partition maps its flake output attrs to the sub-directory backing
  # them (null: the partition directory itself) and a content probe. An attr
  # is only claimed when its backing directory exists and the probe finds
  # content, so the flake never grows empty outputs. The dev attrs carry no
  # probe: their content can come from flake-module.nix modules (git-hooks
  # checks, a treefmt-nix formatter), which discovery cannot see.
  managedPartitions = {
    apps = {
      attrs = {
        apps = {
          hasContent = entriesHasEntries;
        };
      };

      partition = ./partition-apps.nix;
    };

    dev = {
      attrs = {
        checks = { };
        devShells = { };
        formatter = { };
      };

      partition = ./partition-dev.nix;
    };

    flakeModules = {
      attrs = {
        flakeModules = {
          hasContent = entriesHasEntries;
        };
      };

      partition = ./partition-flakeModules.nix;
      subPath = "flake-modules";
    };

    homeManager = {
      attrs = {
        homeConfigurationExtras = {
          subPath = "home-configurations";
          hasContent = partLib.hasEntries partLib.discovery.homeConfigurations;
        };

        homeConfigurations = {
          subPath = "home-configurations";
          hasContent = partLib.hasEntries partLib.discovery.homeConfigurations;
        };

        homeModules = {
          subPath = "modules";
          hasContent = moduleTreeHasEntries;
        };

        homes = {
          subPath = "homes";
          hasContent = moduleTreeHasEntries;
        };
      };

      partition = ./partition-homeManager.nix;
      subPath = "home-manager";
    };

    nixos = {
      attrs = {
        nixosConfigurationExtras = {
          subPath = "systems";
          hasContent = partLib.hasEntries partLib.discovery.systems;
        };

        nixosConfigurations = {
          subPath = "systems";
          hasContent = partLib.hasEntries partLib.discovery.systems;
        };

        nixosModules = {
          subPath = "modules";
          hasContent = moduleTreeHasEntries;
        };
      };

      partition = ./partition-nixos.nix;
    };

    overlays = {
      attrs = {
        overlays = {
          hasContent = moduleTreeHasEntries;
        };
      };

      partition = ./partition-overlays.nix;
    };

    packages = {
      attrs = {
        packages = {
          hasContent = entriesHasEntries;
        };
      };

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
            Path to the partition exposing ${lib.concatStringsSep ", " (lib.attrNames attrs)}
          '';
        };
      }
    ) managedPartitions;
  };

  config =
    let
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
      # Expose nix-utils-lib as an argument to all flake modules. lib rides
      # along because it is a module-system built-in rather than a module
      # argument: it appears in neither _module.args nor specialArgs (nor
      # allModuleArgs), so without this no discovered file could ask for it.
      _module.args = { inherit lib nix-utils-lib; };
      perSystem = {
        _module.args = { inherit lib nix-utils-lib; };
      };

      partitionedAttrs = lib.listToAttrs (
        lib.flatten (
          lib.mapAttrsToList (
            partName:
            {
              attrs,
              optionNamePrefix ? partName,
              ...
            }:
            let
              path = cfg.paths."${optionNamePrefix}Directory";
            in
            lib.mapAttrsToList (
              attr:
              {
                subPath ? null,
                hasContent ? null,
              }:
              let
                backing = if subPath == null then path else path + "/${subPath}";
              in
              lib.optional
                (
                  # Existence first: the content probes read the directory
                  (subPath == null || nix-utils-lib.verifyFileType "directory" backing)
                  && (hasContent == null || hasContent backing)
                )
                {
                  name = attr;
                  value = partName;
                }
            ) attrs
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
              nix-utils-lib.callWithContext (toString partition) (import partition) (
                config._module.args // config._module.specialArgs // { inherit nix-utils-lib; }
              );
        }
        // lib.optionalAttrs (isRegularFile (path + "/flake.nix") && isRegularFile (path + "/flake.lock")) {
          extraInputsFlake = path;
        }
      ) validPartitions;
    };
}
