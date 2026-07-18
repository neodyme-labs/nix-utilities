# Shared machinery for the partition modules: the walk that turns discovered
# paths into flake outputs plus sub-partitions, and the discovery argument
# sets each walk shape uses. Not part of the exported nix-utils-lib surface.
{ lib, nix-utils-lib }:

{
  /**
    One `readImportablePaths` argument set per walk shape. The partitions
    build their `paths` from these, and the claiming logic in
    `../default.nix` probes the same sets via `hasEntries` - sharing them
    is what keeps "which attrs are claimed" and "what a partition
    discovers" from drifting apart.
  */
  discovery = rec {
    # Flat listing: files and default.nix directories (apps, packages,
    # dev, flake-modules).
    entries = dir: {
      inherit dir;

      exclude = [
        "flake.nix"
        "flake-module.nix"
      ];
    };

    # Module trees: files and any directory carrying Nix code (modules
    # walks, homes, overlays). Asset-only directories stay invisible.
    moduleTree = dir: entries dir // { dirIncludibilityCheck = nix-utils-lib.dirContainsNixFiles; };

    # Metadata-carrying directories only (systems, home-configurations):
    # a directory is an entry exactly when it holds the metadata file.
    metadataDirs =
      {
        metadataFile,
        recursive ? false,
      }:
      dir: {
        inherit dir recursive;

        includeRegular = false;
        dirIncludibilityCheck = path: nix-utils-lib.verifyFileType "regular" (path + "/${metadataFile}");
      };

    # Recursive, so FQDN-structured layouts (<tld>/<domain>/<host>) work.
    systems = metadataDirs {
      metadataFile = "system-metadata.nix";
      recursive = true;
    };

    homeConfigurations = metadataDirs { metadataFile = "home-metadata.nix"; };
  };

  /**
    Whether a discovery argument set finds anything in `dir`. Used by the
    claiming logic; only call it on an existing directory (discovery reads
    it with `readDir`).
  */
  hasEntries = spec: dir: nix-utils-lib.readImportablePaths (spec dir) != [ ];

  /**
    Turns discovered paths into a walk result: `flakeOutputs` maps each
    entry's name to its value, and `partitions` holds a sub-partition per
    directory entry, so evaluating one entry never forces another's
    inputs. Files are imported directly via `importFunc`; directories
    become sub-partitions whose module is `flake-module.nix` when present
    and `module` otherwise, with `${subOutputName}Name`/`Path` injected as
    module arguments and the entry value read back from the sub-partition's
    `flake.${subOutputName}`.
  */
  walk =
    {
      importFunc ? import,
      module,
      nameFunc ? nix-utils-lib.stripNixSuffix,
      outputName,
      partitions,
      paths,
      subOutputName,
      ...
    }@walkArgs:
    let
      isRegularFile = nix-utils-lib.verifyFileType "regular";

      walkResult = nix-utils-lib.uniqueListToAttrs (
        map (
          { path, type }@args:
          rec {
            inherit path;
            name = nameFunc args;

            value = {
              value =
                if type == "directory" then
                  partitions."${outputName}.${name}".module.flake.${subOutputName}
                else
                  importFunc path;

              partition =
                lib.optionalAttrs (type == "directory") {
                  module = {
                    imports = [
                      (if isRegularFile (path + "/flake-module.nix") then path + "/flake-module.nix" else module)
                    ];

                    _module.args = {
                      "${subOutputName}Name" = name;
                      "${subOutputName}Path" = path;
                    };
                  };
                }
                # Extra inputs resolve purely only from a lock, so a
                # flake.nix without one is ignored rather than half-wired.
                // lib.optionalAttrs (isRegularFile (path + "/flake.nix") && isRegularFile (path + "/flake.lock")) {
                  extraInputsFlake = path;
                };
            };
          }
        ) paths
      );
    in
    walkArgs
    // {
      flakeOutputs = lib.mapAttrs (_: v: v.value) walkResult;
      partitions = lib.mapAttrs (_: v: v.partition) (
        lib.filterAttrs (_: v: v.partition != { }) walkResult
      );
    };
}
