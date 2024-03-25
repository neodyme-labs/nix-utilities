{ lib }:

with builtins;
with lib;
let
  # * Shorthand for verifying whether a directory is includable
  isDirIncludable =
    path:
    let
      defaultPath = "${path}/default.nix";
    in
    pathExists defaultPath && readFileType defaultPath == "regular";

  # * Function to build the requested import list / attrs
  build =
    {
      asAttrs ? false,
      exclude ? [ ],
      excludeTopLevel ? [ "default.nix" ],
      flattenNames ? false,
      includedTypes ? [
        "regular"
        "directory"
      ],
      isTopLevel ? true,
      path,
      pathParts ? [ ],
      pathSeparator ? "/",
      pathNameReverseOrder ? false,
      recursive ? false,
      removeNixSuffix ? true,
    }@args:
    let
      excluded = if isTopLevel then exclude ++ excludeTopLevel else exclude;
      searchType = if recursive then includedTypes ++ [ "directory" ] else includedTypes;

      pathNameOrder = if pathNameReverseOrder then reverseList else id;

      recurse =
        name: type:
        let
          candidate = path + "/${name}";
          candidateName = if type == "regular" && removeNixSuffix then removeSuffix ".nix" name else name;
          candidateValue =
            if asAttrs then
              {
                name =
                  if flattenNames then
                    candidateName
                  else
                    concatStringsSep pathSeparator (pathNameOrder (pathParts ++ [ candidateName ]));
                value = candidate;
              }
            else
              candidate;
        in
        if type == "directory" then
          if recursive then
            if isDirIncludable candidate then
              if elem "directory" includedTypes then candidateValue else [ ]
            else
              build (
                args
                // {
                  path = candidate;
                  pathParts = pathParts ++ [ name ];
                  isTopLevel = false;
                }
              )
          else if elem "directory" includedTypes && isDirIncludable candidate then
            candidateValue
          else
            [ ]
        else if type == "regular" && elem "regular" includedTypes && hasSuffix ".nix" name then
          candidateValue
        else
          [ ];

      collectionFunc =
        attrs:
        let
          result = flatten (mapAttrsToList recurse attrs);
        in
        if asAttrs && isTopLevel then listToAttrs result else result;
    in
    collectionFunc (
      filterAttrs (name: type: elem type searchType && !elem name excluded) (readDir path)
    );

  presets = {
    all = [
      "directory"
      "regular"
    ];

    nixFiles = [ "regular" ];
    directories = [ "directory" ];
  };
in
{
  inherit isDirIncludable build;
}
// concatMapAttrs (
  name: includedTypes:
  let
    regular =
      args: path:
      build (
        args
        // {
          inherit includedTypes path;
          asAttrs = false;
          recursive = false;
        }
      );

    asAttrs =
      args: path:
      build (
        args
        // {
          inherit includedTypes path;
          asAttrs = true;
          recursive = false;
        }
      );

    recursive =
      args: path:
      build (
        args
        // {
          inherit includedTypes path;
          asAttrs = false;
          recursive = true;
        }
      );

    asAttrsRecursive =
      args: path:
      build (
        args
        // {
          inherit includedTypes path;
          asAttrs = true;
          recursive = true;
        }
      );

    asFlatAttrsRecursive = args: asAttrsRecursive (args // { flattenNames = true; });
  in
  {
    "${name}" = regular { };
    "${name}'" = regular;
    "${name}AsAttrs" = asAttrs { };
    "${name}AsAttrs'" = asAttrs;
    "${name}Recursive" = recursive { };
    "${name}Recursive'" = recursive;
    "${name}AsAttrsRecursive" = asAttrsRecursive { };
    "${name}AsAttrsRecursive'" = asAttrsRecursive;
    "${name}AsFlatAttrsRecursive" = asFlatAttrsRecursive { };
    "${name}AsFlatAttrsRecursive'" = asFlatAttrsRecursive;
  }
) presets
