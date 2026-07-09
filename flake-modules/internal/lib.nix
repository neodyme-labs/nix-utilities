{ lib, nix-utils-lib }:

{
  walk =
    {
      importFunc ? import,
      module,
      nameFunc ? nix-utils-lib.stripNixSuffix,
      outputName,
      partitions,
      paths,
      subOutputName,
      # The flake attribute this walk aggregates from each partition's
      # `flake.*` output - defaults to `subOutputName` (the original
      # behaviour), but can differ from it when a second walk targets the
      # same underlying partitions to pick out a *different* sibling flake
      # attribute (e.g. exposing a lightweight `nixosConfigurationExtra`
      # alongside the real `nixosConfiguration`, from the same module,
      # without needing to also rename the `${subOutputName}Name`/`Path`
      # specialArgs the partition module expects).
      flakeAttr ? subOutputName,
      ...
    }@walkArgs:
    let
      isRegularFile = nix-utils-lib.verifyFileType "regular";

      walkResult = builtins.listToAttrs (
        map (
          { path, type }@args:
          rec {
            name = nameFunc args;

            value = {
              value =
                if type == "directory" then
                  partitions."${outputName}.${name}".module.flake.${flakeAttr}
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
                # Respect flake.{nix,lock}, if present in the directory
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
