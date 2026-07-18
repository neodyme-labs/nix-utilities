_:

{
  /**
    Checks whether a file exists and matches the given type.

    Returns `false` if the file is `null`, does not exist, or its type
    does not match the expected type string.

    A symlink counts as matching `"regular"` and `"directory"`: Nix
    offers no way to stat the target's type, so a target of the wrong
    kind is accepted here and surfaces at use time instead. The same goes
    for dangling links where `pathExists` does not follow them (it is
    lstat-like in Determinate Nix); upstream Nix drops them here.

    # Inputs

    `type`
    : The expected file type (e.g. `"regular"`, `"directory"`, `"symlink"`).

    `file`
    : The path to check.

    # Type

    ```
    verifyFileType :: String -> Path -> Bool
    ```

    # Examples
    :::{.example}
    ## `nix-utils-lib.files.verifyFileType` usage example

    ```nix
    verifyFileType "regular" /etc/hosts
    => true

    verifyFileType "directory" /etc/hosts
    => false

    verifyFileType "regular" null
    => false
    ```

    :::
  */
  verifyFileType =
    type: file:
    with builtins;
    file != null
    && pathExists file
    && (
      let
        # readFileType refuses to traverse intermediate symlinks; typing the
        # entry via its parent's listing follows them, like readDir and
        # import do.
        actual = (readDir (dirOf file)).${baseNameOf file} or null;
      in
      actual == type || (actual == "symlink" && (type == "regular" || type == "directory"))
    );
}
