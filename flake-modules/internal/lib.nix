{ lib, nix-utils-lib }:

rec {
  stripNixSuffix =
    { path, type }:
    if type == "regular" then lib.removeSuffix ".nix" (baseNameOf path) else baseNameOf path;

  walk =
    {
      importFunc ? import,
      module,
      nameFunc ? stripNixSuffix,
      outputName,
      partitions,
      paths,
      subOutputName,
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
