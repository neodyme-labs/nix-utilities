# Release notes

## v2

v2 is a complete rewrite. The library moves from a single flake-parts module
configured through options to a family of [flake-parts
partitions](https://flake.parts/options/flake-parts-partitions.html) driven
purely by directory conventions: outputs are discovered from the layout, and
evaluating one output never fetches or evaluates the inputs of another.
There is no in-place migration path - treat the upgrade as adopting a new
library. The [README](README.md) documents the current behaviour in full;
these notes summarise what changed relative to the first generation.

### Staying on the legacy version

The previous generation remains available on the
[`legacy`](https://github.com/neodyme-labs/nix-utilities/tree/legacy)
branch:

```nix
nix-utilities.url = "github:neodyme-labs/nix-utilities/legacy";
```

It is kept as-is and receives no further development.

### The new model

- **Options become conventions.** The legacy `nixUtilities.nixos.hosts` and
  `nixUtilities.home.homes` option trees (per-host submodules, `defaults`,
  `importAllModules`, `inlineModules`, `versions`, ...) are gone. A NixOS
  system is a directory under `nixos/systems/` carrying a
  `system-metadata.nix`; everything else is discovered. The only options
  left are `nixUtilities.root` and the per-partition `nixUtilities.paths.*`
  overrides.
- **Partitions instead of one evaluation.** Every part of the layout
  (packages, dev tooling, each NixOS system, each home) lives in its own
  flake-parts partition with optional partition-local inputs (a nested
  `flake.nix` + `flake.lock`), replacing the legacy `versions` machinery
  for pinning different nixpkgs per host. Any partition's implementation
  can be replaced wholesale with a `flake-module.nix`.
- **The multi-version machinery is gone.** Instead of
  `nixUtilities.versions.<name>` and per-host `version` options, a host or
  home pins its own inputs via its partition-local flake, and its metadata
  selects `nixpkgs` (and `home-manager`) from the inputs in scope.

### Layout changes

```
legacy                          v2
root/apps                       root/apps
root/checks                     root/dev/checks
root/shells                     root/dev/shells
                                root/dev/formatter.nix        (new)
                                root/flake-modules            (new)
root/home-manager/default-home  removed - use a home or module
root/home-manager/homes         root/home-manager/homes                (now modules, see below)
                                root/home-manager/home-configurations  (new, built homes)
root/home-manager/modules       root/home-manager/modules
root/nixos/modules              root/nixos/modules
root/nixos/systems              root/nixos/systems
root/nixpkgs-config             removed - use metadata config/overlays
root/overlays                   root/overlays
root/packages                   root/packages
```

### Outputs and behaviour

- **NixOS systems**: discovered recursively, so FQDN-structured layouts
  (`systems/<tld>/<domain>/<host>/`) name their configurations by FQDN.
  `system-metadata.nix` takes `hostPlatform` (required), `modules`,
  `nixpkgs`, `overlays` and free-form `extra` facts, exposed through the
  new `nixosConfigurationExtras` output - readable without forcing any
  host's evaluation. Modules receive `hostInputs`,
  `nixosConfigurationName`, `nixosConfigurationPath` and
  `nixosConfigurationExtra`.
- **Homes are split in two.** `home-manager/homes/` holds per-user home
  *modules*, exposed as the new `flake.homes` output and meant for
  embedding into hosts (where `osConfig` and the host's package set are
  available). `home-manager/home-configurations/` builds real switchable
  `homeManagerConfiguration`s from directories carrying a
  `home-metadata.nix`; configurations name their home explicitly (e.g.
  `modules = [ self.homes.alice ];`) and expose `extra` facts through
  `homeConfigurationExtras`. The legacy `default-home` concept is gone -
  model it as a home or shared module.
- **New outputs**: `flakeModules` (from `flake-modules/`), a `formatter`
  (from `dev/formatter.nix`, deliberately weaker than treefmt-nix's
  priority), and the two extras aggregates.
- **Overlays**: files are whole overlays; a directory composes its
  attrset-returning parts via `composeManyExtensions` in alphabetical
  order.
- **Packages** are called `callPackage`-style with automatic extra
  arguments (flake-parts module arguments, `inputs`, `self`, `lib`,
  `nix-utils-lib`); `pkgs` wins name collisions, so `config` and `lib`
  keep their nixpkgs meaning.
- **Outputs only exist when backed by content**: an existing-but-empty
  directory claims nothing, and definitions made at the flake's top level
  for generated attributes do not merge (see the README caveats).
- **Discovery is strict where it used to be silent**: two entries mapping
  to the same name are an error instead of a silent shadowing, symlinks
  count as their target where Nix can inspect them, and asset-only
  directories stay invisible.
- **The extraArgs convention**: discovered files may be wrapped in one
  extra function layer receiving the partition's module arguments; see the
  README for the wrapper's documented limits.

### The library

`nix-utilities.lib` (injected everywhere as `nix-utils-lib`) is a new API.
The legacy `imports.build`/presets and the `utils` submodule helpers
(`mkSubmodule`, `mkSubmoduleExtension`) are gone; v2 ships the discovery
walk (`readImportablePaths`, `importAsAttrs`, includibility checks,
`uniqueListToAttrs`, `stripNixSuffix`), calling helpers (`callWith`,
`callWithIfNestedFunc` and their context-carrying variants) and
`verifyFileType`. The set is built with `makeExtensible` and can be
extended via `.extend`.

### Removed

- The `nixUtilities.nixos.*` / `nixUtilities.home.*` / `versions` option
  trees, `nixpkgs-config/`, `default-home/`, and the options documentation
  generator (`packages/docs.nix`).
- The bundled `example/` project; the README's recipes replace it.
