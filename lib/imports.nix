{ lib, nix-utils-lib }:

let
  inherit (nix-utils-lib) verifyFileType;
in
rec {
  /**
    Like `builtins.listToAttrs`, but throws when several entries map to the
    same attribute name instead of silently keeping the first one. Entries
    may carry a `path` attribute, which is used in the error message to
    point at the colliding sources (e.g. `foo.nix` next to `foo/`).

    # Inputs

    `list`
    : List of `{ name, value }` sets, optionally with a `path` attribute.

    # Type

    ```
    uniqueListToAttrs :: [ { name :: String, value :: Any, path :: Path? } ] -> AttrSet
    ```
  */
  uniqueListToAttrs =
    list:
    let
      duplicates = lib.filterAttrs (_: entries: builtins.length entries > 1) (
        lib.groupBy (entry: entry.name) list
      );

      describe =
        name: entries:
        "`${name}` (from: ${
          lib.concatMapStringsSep ", " (entry: toString (entry.path or "<unknown path>")) entries
        })";
    in
    if duplicates == { } then
      builtins.listToAttrs list
    else
      throw "uniqueListToAttrs: multiple entries map to the same attribute name: ${lib.concatStringsSep "; " (lib.mapAttrsToList describe duplicates)}";

  /**
    Discovery plus import: runs `readImportablePaths` and turns the result
    into an attribute set, named via `nameFunc` and valued via
    `importFunc`. Name collisions throw (see `uniqueListToAttrs`).

    # Inputs

    `nameFunc`
    : Maps a discovered `{ path, type }` entry to its attribute name.

    `importFunc`
    : Maps a discovered entry to its value.

    All other attributes are passed through to `readImportablePaths`.

    # Type

    ```
    importAsAttrs :: {
      nameFunc :: ({ path, type } -> String)?,
      importFunc :: ({ path, type } -> Any)?,
      ...
    } -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `nix-utils-lib.imports.importAsAttrs` usage example

    ```nix
    importAsAttrs { dir = ./modules; }
    => { service = <imported ./modules/service.nix>; }
    ```

    :::
  */
  importAsAttrs =
    {
      nameFunc ? stripNixSuffix,
      importFunc ? ({ path, ... }: import path),
      ...
    }@args:
    uniqueListToAttrs (
      map
        (
          { path, ... }@mapArgs:
          {
            inherit path;
            name = nameFunc mapArgs;
            value = importFunc mapArgs;
          }
        )
        (
          readImportablePaths (
            removeAttrs args [
              "nameFunc"
              "importFunc"
            ]
          )
        )
    );

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
    Checks whether a directory contains any Nix file, at any depth. Useful
    as a `dirIncludibilityCheck` where every directory carrying Nix code
    should become a sub-partition, while asset directories (patches, keys,
    ...) stay invisible.

    A `flake.nix` does not count: it declares inputs, not importable code,
    so an asset directory pinning its sources stays invisible.

    Returns `false` when `dir` is not a real directory - in particular for
    symlinks, whatever they point at. Discovery hands this check symlinked
    (possibly dangling) candidates, and Nix offers no way to inspect a
    link's target without an uncatchable error on the wrong kind; refusing
    links entirely keeps the check total. This also matches
    `readImportablePaths`, which never descends into symlinked
    directories, so a directory whose Nix files sit exclusively behind one
    does not count.

    # Inputs

    `dir`
    : The directory to scan.

    # Type

    ```
    dirContainsNixFiles :: Path -> Bool
    ```
  */
  dirContainsNixFiles =
    dir:
    # Typed via the parent listing: readDir on anything but a real
    # directory (a symlink to one included) is uncatchable.
    (builtins.readDir (dirOf dir)).${baseNameOf dir} or null == "directory"
    &&
      readImportablePaths {
        inherit dir;
        exclude = [ "flake.nix" ];
        includeDirectories = false;
        recursive = true;
      } != [ ];

  /**
    Recursively or shallowly finds importable Nix paths within a directory.

    Symlinks are treated as their target: a `.nix` name counts as a regular
    file, anything else as a directory candidate. Nix cannot inspect a
    link's target during discovery, so a dangling `.nix` link fails at
    import time, and whether other dangling links are dropped here or
    reach the `dirIncludibilityCheck` depends on the Nix implementation
    (`pathExists` follows links upstream, but is lstat-like in Determinate
    Nix). The check must therefore tolerate symlinked and dangling
    candidates; the checks in this library do. Symlinked directories are
    never recursed into.

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
                path = fullPath name;

                # A symlink acts as its target; import and readDir follow
                # links, but readDir cannot report the target's type, so the
                # name has to decide. Symlinked directories are never
                # recursed into, which keeps cycles impossible. The
                # pathExists guard only drops dangling links where it
                # follows them (it is lstat-like in Determinate Nix), so
                # directory candidates may be dangling and the
                # dirIncludibilityCheck has to stay total on them.
                effectiveType =
                  if type != "symlink" then
                    type
                  else if !builtins.pathExists path then
                    null
                  else if lib.hasSuffix ".nix" name then
                    "regular"
                  else
                    "directory";

                candidate = {
                  inherit path;
                  type = effectiveType;
                };
              in
              if includeRegular && effectiveType == "regular" && lib.hasSuffix ".nix" name then
                candidate
              else if includeDirectories && effectiveType == "directory" && dirIncludibilityCheck path then
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

  /**
    The naming rule for discovered entries: regular files lose their
    `.nix` suffix, directories keep their plain name.

    # Inputs

    `entry`
    : A `{ path, type }` entry as returned by `readImportablePaths`.

    # Type

    ```
    stripNixSuffix :: { path :: Path, type :: String } -> String
    ```

    # Examples
    :::{.example}
    ## `nix-utils-lib.imports.stripNixSuffix` usage example

    ```nix
    stripNixSuffix { path = ./modules/service.nix; type = "regular"; }
    => "service"
    ```

    :::
  */
  stripNixSuffix =
    { path, type }:
    if type == "regular" then lib.removeSuffix ".nix" (baseNameOf path) else baseNameOf path;
}
