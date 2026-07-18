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
  {
    files = callLibs ./files.nix;
    functions = callLibs ./functions.nix;
    imports = callLibs ./imports.nix;

    # Alias through the fixpoint (not rec) so `extend` overrides propagate
    inherit (self.files) verifyFileType;

    inherit (self.functions)
      callWith
      callWithContext
      callWithIfNestedFunc
      callWithIfNestedFuncContext
      ;

    inherit (self.imports)
      dirContainsNixFiles
      importAsAttrs
      isDirectoryIncludible
      readImportablePaths
      stripNixSuffix
      uniqueListToAttrs
      ;
  }
)
