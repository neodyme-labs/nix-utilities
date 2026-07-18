{
  lib,
  pkgs,
  nix-utils-lib,
}:

let
  inherit (nix-utils-lib)
    callWith
    callWithIfNestedFunc
    dirContainsNixFiles
    importAsAttrs
    isDirectoryIncludible
    readImportablePaths
    stripNixSuffix
    uniqueListToAttrs
    verifyFileType
    ;

  fixtures = ./fixtures;
  discovery = fixtures + "/discovery";
  claiming = fixtures + "/claiming";

  # The internal partition machinery is not part of nix-utils-lib, but its
  # discovery specs decide which flake outputs get claimed - test them too.
  partLib = import ../../flake-modules/internal/lib.nix { inherit lib nix-utils-lib; };

  baseNames = args: lib.naturalSort (map ({ path, ... }: baseNameOf path) (readImportablePaths args));

  throws = expr: !(builtins.tryEval expr).success;

  # Discovery fixture, for reference:
  #   a.nix, excluded.nix           - regular files
  #   b/default.nix                 - includible directory
  #   assets/data.txt               - directory without nix files
  #   nested/inner.nix              - nix file behind a non-includible directory
  #   link-file.nix -> a.nix        - symlink with a .nix name
  #   link-dir -> b                 - symlink to an includible directory
  #   link-plain -> assets/data.txt - symlink to a non-nix regular file
  #   dangling -> missing           - dangling symlink
  tests = {
    shallow-discovery =
      baseNames {
        dir = discovery;
        exclude = [ "excluded.nix" ];
      } == [
        "a.nix"
        "b"
        "link-dir"
        "link-file.nix"
      ];

    no-exclude =
      baseNames { dir = discovery; } == [
        "a.nix"
        "b"
        "excluded.nix"
        "link-dir"
        "link-file.nix"
      ];

    # Symlinked directories are never recursed into; real ones are entered
    # even when they are candidates themselves (b/default.nix shows up).
    recursive-files =
      baseNames {
        dir = discovery;
        exclude = [ "excluded.nix" ];
        includeDirectories = false;
        recursive = true;
      } == [
        "a.nix"
        "default.nix"
        "inner.nix"
        "link-file.nix"
      ];

    # import follows symlinks, so linked entries resolve to their targets.
    import-follows-links =
      let
        imported = importAsAttrs {
          dir = discovery;
          exclude = [ "excluded.nix" ];
        };
      in
      lib.mapAttrs (_: value: value.fixture) imported == {
        a = "a";
        b = "b";
        link-dir = "b";
        link-file = "a";
      };

    includible-directory = isDirectoryIncludible (discovery + "/b");
    includible-through-link = isDirectoryIncludible (discovery + "/link-dir");
    not-includible-without-default = !isDirectoryIncludible (discovery + "/nested");

    contains-nix-files = dirContainsNixFiles (discovery + "/nested");
    no-nix-files = !dirContainsNixFiles (discovery + "/assets");
    flake-nix-does-not-count = !dirContainsNixFiles (fixtures + "/flakeonly");

    # Nix cannot inspect a symlink's target, so the check must refuse links
    # instead of crashing in readDir (uncatchable on non-directories).
    refuses-link-to-directory = !dirContainsNixFiles (discovery + "/link-dir");
    refuses-link-to-file = !dirContainsNixFiles (discovery + "/link-plain");
    refuses-dangling-link = !dirContainsNixFiles (discovery + "/dangling");

    # Discovery specs shared between partitions and output claiming.
    # Claiming fixture: modules-like/ (flake.nix + mod.nix + assets),
    # systems-like/ (host1/, one/example/host2/ with metadata, one without),
    # home-configs/ (alice/ with metadata, bob/ without), empty-ish/.
    spec-module-tree =
      baseNames (partLib.discovery.moduleTree (claiming + "/modules-like")) == [ "mod.nix" ];

    spec-systems-recursive =
      baseNames (partLib.discovery.systems (claiming + "/systems-like")) == [
        "host1"
        "host2"
      ];

    spec-home-configurations =
      baseNames (partLib.discovery.homeConfigurations (claiming + "/home-configs")) == [ "alice" ];

    has-entries = partLib.hasEntries partLib.discovery.moduleTree (claiming + "/modules-like");
    has-no-entries = !partLib.hasEntries partLib.discovery.moduleTree (claiming + "/empty-ish");

    # A stray flake.nix is inputs, not content, in both walk shapes.
    entries-ignore-stray-flake =
      baseNames (partLib.discovery.entries (claiming + "/modules-like")) == [ "mod.nix" ];

    verify-regular = verifyFileType "regular" (discovery + "/a.nix");
    verify-directory = verifyFileType "directory" (discovery + "/b");
    verify-wrong-type = !verifyFileType "regular" (discovery + "/b");
    verify-missing = !verifyFileType "regular" (discovery + "/missing.nix");
    # Symlink targets cannot be stated, so a link passes for both kinds and
    # a wrong target surfaces at use time.
    verify-link-as-regular = verifyFileType "regular" (discovery + "/link-file.nix");
    verify-link-as-directory = verifyFileType "directory" (discovery + "/link-plain");

    unique-attrs =
      uniqueListToAttrs [
        {
          name = "x";
          value = 1;
        }
        {
          name = "y";
          value = 2;
        }
      ] == {
        x = 1;
        y = 2;
      };

    unique-attrs-duplicate-throws = throws (uniqueListToAttrs [
      {
        name = "x";
        value = 1;
      }
      {
        name = "x";
        value = 2;
      }
    ]);

    # foo.nix next to foo/ is an error, not a silent shadowing.
    duplicate-names-throw = throws (
      builtins.attrNames (importAsAttrs {
        dir = fixtures + "/dup";
      })
    );

    strip-nix-suffix =
      stripNixSuffix {
        path = discovery + "/a.nix";
        type = "regular";
      } == "a"
      &&
        stripNixSuffix {
          path = discovery + "/b";
          type = "directory";
        } == "b";

    call-with-selects-args =
      callWith ({ a, b }: a + b) {
        a = 1;
        b = 2;
        c = 3;
      } == 3;
    call-with-defaults =
      callWith (
        {
          a,
          b ? 10,
        }:
        a + b
      ) { a = 5; } == 15;
    call-with-missing-throws = throws (callWith ({ a }: a) { });
    call-with-non-function = callWith "not-a-function" { } == "not-a-function";
    call-with-plain-lambda = callWith (args: args.a) { a = 1; } == 1;

    unwraps-named-wrapper =
      let
        result = callWithIfNestedFunc 1 ({ x }: { y }: y + x) { x = 1; };
      in
      result { y = 2; } == 3;

    unwraps-plain-wrapper =
      let
        result = callWithIfNestedFunc 1 (extraArgs: { config }: { value = extraArgs.foo; }) { foo = 1; };
      in
      (result { config = null; }).value == 1;

    keeps-plain-module =
      let
        result = callWithIfNestedFunc 1 ({ config }: { value = config; }) { };
      in
      builtins.isFunction result && (result { config = 7; }).value == 7;

    # Documented limitation: an ellipsis-only wrapper pattern probes as
    # depth 1 and is not unwrapped. The wrapper lives in a fixture because
    # its { ... } pattern must not be "fixed" to _ by statix - the two
    # probe differently, which is the point.
    ellipsis-wrapper-not-unwrapped = builtins.isFunction (
      (callWithIfNestedFunc 1 (import (fixtures + "/functions/ellipsis-wrapper.nix")) { }) { }
    );

    keeps-overlay =
      let
        result = callWithIfNestedFunc 2 (final: prev: { inherit (prev) a; }) { };
      in
      (result null { a = 1; }).a == 1;

    unwraps-wrapped-overlay =
      let
        result = callWithIfNestedFunc 2 ({ flag }: final: prev: { inherit flag; }) { flag = true; };
      in
      (result null null).flag;
  };

  failed = builtins.attrNames (lib.filterAttrs (_: ok: !ok) tests);
in
assert lib.assertMsg (failed == [ ]) "nix-utils-lib tests failed: ${toString failed}";
pkgs.emptyFile
