_:

{
  /**
    Checks whether a file exists and matches the given type.

    Returns `false` if the file is `null`, does not exist, or its type
    does not match the expected type string.

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
    type: file: with builtins; file != null && pathExists file && readFileType file == type;
}
