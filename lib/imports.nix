{ lib, nix-utils-lib }:

let
  inherit (nix-utils-lib) verifyFileType;
in
rec {
  /**
    `isDirectoryIncludible` checks if a directory contains a regular `default.nix` file,
    making it suitable for Nix importation.

    # Inputs

    `dir`
    : The directory path to check for a `default.nix` file.

    # Type

    ```
    isDirectoryIncludible :: Path -> Bool
    ```

    # Examples
    :::{.example}
    ## `nix-utils-lib.imports.isDirectoryIncludible` usage example

    ```nix
    isDirectoryIncludible ./modules/nixos
    => true

    isDirectoryIncludible ./images
    => false
    ```

    :::
  */
  isDirectoryIncludible = dir: verifyFileType "regular" (dir + "/default.nix");

  /**
    Recursively or shallowly finds importable Nix paths within a directory.

    # Inputs

    `dir`
    : The base directory to scan.

    `dirIncludibilityCheck`
    : Function used to check whether a given path is includible.

    `exclude`
    : List of file or directory names to ignore at all levels.

    `excludeTopLevel`
    : List of names to ignore only at the root of `dir`.

    `includeDirectories`
    : Whether to include directory paths in the result.

    `includeRegular`
    : Whether to include regular `.nix` files in the result.

    `recursive`
    : Whether to search subdirectories recursively.

    # Type

    ```
    readImportablePaths :: {
      dir :: Path,
      dirIncludibilityCheck :: Path -> Bool,
      exclude :: [ String ],
      excludeTopLevel :: [ String ],
      includeDirectories :: Bool,
      includeRegular :: Bool,
      recursive :: Bool
    } -> [ { path :: Path, type :: String } ]
    ```

    # Examples
    :::{.example}
    ## `nix-utils-lib.imports.readImportablePaths` usage example

    ```nix
    readImportablePaths { dir = ./modules; recursive = true; }
    => [ { path = /home/user/repo/modules/service.nix; type = "regular"; } ]

    readImportablePaths { dir = ./.; exclude = [ "tests" ]; }
    => [ { path = /home/user/repo/default.nix; type = "regular"; } ]
    ```

    :::
  */
  readImportablePaths =
    {
      dir,
      dirIncludibilityCheck ? isDirectoryIncludible,
      exclude ? [ ],
      excludeTopLevel ? [ ],
      includeDirectories ? true,
      includeRegular ? true,
      recursive ? false,
    }:
    let
      recurse =
        {
          parts,
          topLevel ? false,
        }:
        let
          excluded = exclude ++ lib.optionals topLevel excludeTopLevel;

          fullPath = name: dir + "/${lib.concatStringsSep "/" (parts ++ [ name ])}";
        in
        lib.flatten (
          lib.mapAttrsToList
            (
              name: type:
              let
                candidate = {
                  inherit type;
                  path = fullPath name;
                };
              in
              if includeRegular && type == "regular" && lib.hasSuffix ".nix" name then
                candidate
              else if includeDirectories && dirIncludibilityCheck (fullPath name) then
                candidate
              else if recursive && type == "directory" then
                recurse { parts = parts ++ [ name ]; }
              else
                [ ]
            )
            (
              lib.filterAttrs (name: _: !lib.elem name excluded) (
                builtins.readDir (dir + "/${lib.concatStringsSep "/" parts}")
              )
            )
        );
    in
    recurse {
      parts = [ ];
      topLevel = true;
    };
}
