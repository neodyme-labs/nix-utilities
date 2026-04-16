{ lib }:

lib.makeExtensible (
  self:
  let
    callLibs =
      file:
      import file {
        inherit lib;

        nix-utils-lib = self;
      };
  in
  rec {
    files = callLibs ./files.nix;
    functions = callLibs ./functions.nix;
    imports = callLibs ./imports.nix;

    inherit (files) verifyFileType;

    inherit (functions)
      callWith
      callWithIfNestedFunc
      mockCall'
      mockCall
      mockEval'
      mockEval
      ;

    inherit (imports) isDirectoryIncludible readImportablePaths;
  }
)
