# Nix Utilities

An opinionated flake module for structuring Nix projects: it imports your
flake outputs from a conventional directory layout, and keeps evaluation lean
by placing every part of that layout in its own
[flake-parts](https://flake.parts/) partition, so that evaluating one output
never has to fetch or evaluate the inputs of another. This page covers the
layout, the recipes, and the sharp edges; the flake-parts documentation is a
good primer if partitions are new to you.

> [!IMPORTANT]
> This is the second generation (v2) of nix-utilities, a complete rewrite of
> the original. See [RELEASE-NOTES.md](RELEASE-NOTES.md) for what changed;
> the previous generation remains available on the
> [`legacy`](https://github.com/neodyme-labs/nix-utilities/tree/legacy)
> branch.

## How do I...

### Get started

```nix
{
  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };

    nix-utilities = {
      url = "github:neodyme-labs/nix-utilities";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs-lib.follows = "nixpkgs-lib";
      };
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
  };

  outputs =
    inputs@{ flake-parts, nix-utilities, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ nix-utilities.flakeModules.default ];

      nixUtilities.root = ./nix;

      systems = [ "x86_64-linux" ];
    };
}
```

The `flake-parts.follows` line is load-bearing - see "One flake-parts
instance" under caveats. `inputs.nixpkgs` is the fallback package set for
NixOS systems and home configurations; partitions that need nothing from it
never fetch it.

All paths live under `nixUtilities.root` and can be overridden individually
through the `nixUtilities.paths.*` options (shown in parentheses):

```
<root>/
+-- apps/                 apps partition           (paths.appsDirectory)
+-- dev/                  dev partition            (paths.devDirectory)
|   +-- checks/
|   +-- shells/
|   +-- formatter.nix
+-- flake-modules/        flakeModules partition   (paths.flakeModulesDirectory)
+-- home-manager/         homeManager partition    (paths.homeManagerDirectory)
|   +-- home-configurations/
|   +-- homes/
|   +-- modules/
+-- nixos/                nixos partition          (paths.nixosDirectory)
|   +-- modules/
|   +-- systems/
+-- overlays/             overlays partition       (paths.overlaysDirectory)
+-- packages/             packages partition       (paths.pkgsDirectory)
```

Every directory is optional: a partition only exists when its directory
does, and an output attribute is only claimed when discovery finds content
backing it (see "Partitions and output claiming").

### Add a package, app, check, or dev shell

Drop a file (or a directory with a `default.nix`) into the matching
directory; it is exposed under its name with the `.nix` suffix dropped:

- `packages/` -> `perSystem.packages`, called in `callPackage` style:
  package inputs come from `pkgs`, and the flake-parts
  [perSystem module arguments](https://flake.parts/module-arguments#persystem-module-parameters),
  `inputs`, `self`, `lib` and `nix-utils-lib` are available as automatic
  arguments. A standard `{ stdenv, lib }: ...` file works unchanged;
  `.override` keeps working. Where names collide, `pkgs` wins: `config` and
  `lib` mean what they mean in nixpkgs.
- `apps/` -> `perSystem.apps`; `dev/checks/` -> `perSystem.checks`;
  `dev/shells/` -> `perSystem.devShells`. Files are called (via
  `nix-utils-lib.callWith`) with exactly the arguments they ask for,
  selected from the same set as packages plus everything else in
  `allModuleArgs`.
- `dev/formatter.nix` -> `perSystem.formatter`, called like a package, at
  priority 1001 - one step weaker than `lib.mkDefault`, so modules like
  [treefmt-nix](https://github.com/numtide/treefmt-nix) can take over the
  formatter without friction.

### Add an overlay

`overlays/` -> `flake.overlays`:

- A file is a whole overlay (`final: prev: { ... }`), optionally wrapped
  per the extraArgs convention (`extraArgs: final: prev: { ... }`).
- A directory becomes a sub-partition (injected arguments: `overlayName`,
  `overlayPath`). Its `default.nix`, if present, is the whole overlay;
  otherwise every file is an ordinary attrset-returning overlay part, and
  all parts are composed (via `lib.composeManyExtensions`) in alphabetical
  order, later parts seeing earlier ones through `prev`.

### Add a NixOS module or system

`nixos/modules/` -> `flake.nixosModules`:

- Files support the extraArgs convention and are exposed directly.
- Directories become sub-partitions (injected arguments: `nixosModuleName`,
  `nixosModulePath`). The module tree is discovered as described under
  "Discovery rules" and exposed as a single module.

`nixos/systems/` -> `flake.nixosConfigurations`. A system is a directory
containing a `system-metadata.nix`; the tree is searched recursively, so
FQDN-structured layouts work - `systems/one/example/host/` becomes
`nixosConfigurations."host.example.one"`:

```
systems/
+-- <host>/
|   +-- system-metadata.nix   - Required; see below
|   +-- ...                   - Module tree, discovered as usual
+-- <tld>/<domain>/<host>/
    -- same, for FQDN-structured layouts --
```

Each system is a sub-partition (injected arguments:
`nixosConfigurationName`, `nixosConfigurationPath`); the configuration is
built with `nixpkgs.lib.nixosSystem` from the discovered module tree plus
the metadata below.

`system-metadata.nix` contains an attribute set, or a function to one
supporting the extraArgs argument set:

| Attribute      | Optional | Usage                                                         |
| -------------- | -------- | ------------------------------------------------------------- |
| `hostPlatform` | No       | Platform (system) of the configuration.                       |
| `modules`      | Yes      | List of modules included in the configuration.                |
| `nixpkgs`      | Yes      | The nixpkgs flake being used. Falls back to `inputs.nixpkgs`. |
| `overlays`     | Yes      | List of overlays applied to the nixpkgs.                      |
| `extra`        | Yes      | Arbitrary host facts exposed via `nixosConfigurationExtras`.  |

Two extra pieces of plumbing:

- `flake.nixosConfigurationExtras.<name>` mirrors each host's `extra`
  metadata. Reading it never forces that host's module tree, unlike
  `nixosConfigurations.<name>.config`, which makes it cheap ground truth
  for tooling that walks every host (CODEOWNERS generators, secrets
  tooling, ...).
- Modules inside a configuration receive the specialArg `hostInputs`: the
  host's own fully resolved inputs (root inputs merged with the host's
  `flake.nix` inputs, if any). It is deliberately named differently from a
  module's own eagerly resolved `inputs`, so a shared module can prefer a
  host's override while falling back to what it already has, e.g.
  `inputs // hostInputs`.

Also injected as module arguments: `nixosConfigurationName`,
`nixosConfigurationPath` and `nixosConfigurationExtra` (this host's own
`extra`).

### Add a home

`home-manager/homes/` -> `flake.homes`: one entry per user home, with
exactly the same shape as modules (files support the extraArgs convention;
directories become sub-partitions with injected arguments `homeName`,
`homePath`, and are exposed as a single module).

A home is a home-manager *module*, not a built configuration - homes are
typically embedded into hosts, where they can read `osConfig` and use each
host's own package set:

```nix
home-manager.users.alice = self.homes.alice;
```

`homes/` is deliberately separate from `modules/`: in multi-user
environments, per-person homes and shared building blocks diverge - homes
reference modules, carry per-person inputs, and are managed per user, while
`home-manager/modules/` -> `flake.homeModules` holds the shared modules
they import.

### Add a standalone home configuration

`home-manager/home-configurations/` -> `flake.homeConfigurations`: a
configuration is a directory containing a `home-metadata.nix`, built with
`home-manager.lib.homeManagerConfiguration` into a real (switchable)
configuration for `home-manager switch --flake`.

Configurations pull nothing in implicitly: name what you want, typically a
home from `homes/`, in the metadata's `modules` -

```nix
# home-manager/home-configurations/alice/home-metadata.nix
{ self, ... }:
{
  hostPlatform = "x86_64-linux";
  modules = [ self.homes.alice ];
}
```

- plus the configuration directory's own module tree, discovered as usual.
  Because the build bakes in one platform and has no host to read `osConfig`
  from, host-adaptive homes belong in `homes/` and get embedded; standalone
  configurations suit self-contained setups (a laptop, a dev container).

`home-metadata.nix` contains an attribute set, or a function to one
supporting the extraArgs argument set:

| Attribute          | Optional | Usage                                                               |
| ------------------ | -------- | ------------------------------------------------------------------- |
| `hostPlatform`     | No       | Platform (system) of the configuration.                             |
| `modules`          | Yes      | Modules included in the configuration (e.g. `self.homes.<name>`).   |
| `nixpkgs`          | Yes      | The nixpkgs flake to use. Falls back to `inputs.nixpkgs`.           |
| `home-manager`     | Yes      | The home-manager flake to use. Falls back to `inputs.home-manager`. |
| `config`           | Yes      | nixpkgs configuration (`allowUnfree`, ...) for the package set.     |
| `overlays`         | Yes      | Overlays applied to the package set.                                |
| `extraSpecialArgs` | Yes      | Extra `specialArgs` passed to the home-manager modules.             |
| `extra`            | Yes      | Arbitrary facts exposed via `homeConfigurationExtras`.              |

`flake.homeConfigurationExtras.<name>` mirrors each configuration's
`extra` without forcing its build, like `nixosConfigurationExtras`.
Configurations receive the specialArg `hostInputs` and the module arguments
`homeConfigurationName`, `homeConfigurationPath` and
`homeConfigurationExtra`.

### Override or extend a partition

Every (sub-)partition directory supports two special files:

- `flake.nix` together with `flake.lock`: additional inputs available
  (merged over the root inputs) only within that partition. Both files must
  be present. This repository's [dev](./dev/) directory pins its
  development dependencies this way.
- `flake-module.nix`: replaces our implementation of the partition with
  your own flake-parts module. Injected module arguments (such as
  `nixosConfigurationPath`) stay available. This repository's
  [dev/flake-module.nix](./dev/flake-module.nix) uses this to add extra
  tooling on top of the stock dev partition. Note that which flake output
  attributes are claimed from the partition still follows the stock
  directory conventions - a replacement implementation has to keep the
  layout, or wire diverging outputs itself.

To add to or change a generated output, do it inside the partition: drop a
file into its directory, or override the partition with a
`flake-module.nix`. Defining the same attribute at the flake's top level
does not work (see caveats).

## How it works

### Partitions and output claiming

Each top-level directory becomes a flake-parts partition: a separate module
system evaluation providing a fixed set of flake output attributes.
Sub-directories of the homeManager, nixos and overlays partitions become
nested sub-partitions of their own.

An output attribute exists exactly when discovery finds content backing it:
the claiming logic in
[flake-modules/default.nix](./flake-modules/default.nix) probes each
attribute's backing directory with the same discovery rules its partition
uses (shared via
[flake-modules/internal/lib.nix](./flake-modules/internal/lib.nix)), so an
existing-but-empty directory claims nothing and the flake never grows empty
outputs. The one exception is dev: `dev/` existing claims `checks`,
`devShells` and `formatter` outright, because their content typically comes
from `flake-module.nix` modules (git-hooks adding a pre-commit check,
treefmt-nix providing the formatter), which discovery cannot see.

Partitioned attributes are wired into the flake with `lib.mkForce`
(flake-parts' `partitionedAttrs` machinery).

### Discovery rules

- Regular files are exposed under their name with the `.nix` suffix
  dropped; directories under their plain name.
- Two entries mapping to the same name (`foo.nix` next to `foo/`) are an
  error, not a silent shadowing.
- Which directories are included depends on the partition. The modules,
  homes and overlays walks take any directory carrying a `.nix` file at any
  depth (`flake.nix` does not count), so asset directories (patch
  collections, keys, ...) stay invisible. apps, packages, dev and
  flake-modules only take directories with a `default.nix`; systems and
  home-configurations only take directories with their metadata file.
- Symlinks count as their target: a `.nix` name is treated as a file,
  anything else as a directory candidate. Symlinked directories are never
  recursed into, and only count where the inclusion probe passes through
  the link (a `default.nix` or metadata file behind it) - the modules,
  homes and overlays walks cannot inspect a link's target and never take
  symlinked directories. A dangling `.nix` link fails at import time; other
  dangling links are ignored.
- Where a directory is imported as a module tree, a `default.nix` takes
  precedence: if present it is imported as the whole tree, otherwise all
  `.nix` files and includible directories are collected recursively.

### The extraArgs convention

Files documented above as supporting extra arguments may optionally be
wrapped in one more function layer:

```nix
# Plain form
{ config, ... }: { ... }

# Wrapped form - extraArgs receives _module.args // _module.specialArgs
# // { inherit nix-utils-lib; } of the surrounding partition
{ inputs, nix-utils-lib, ... }: { config, ... }: { ... }
```

The wrapper is detected by speculatively probing the function's arity; see
the caveats for the two limits this brings.

### The library

`nix-utilities.lib` (also injected everywhere as the module argument
`nix-utils-lib`) carries the helpers the partitions are built from, usable
on their own:

- `files.verifyFileType`: existence-and-type check that treats symlinks as
  their targets.
- `functions.callWith` / `callWithContext`: call a function with only the
  arguments it asks for; the context variant names the call site in
  missing-argument errors.
- `functions.callWithIfNestedFunc` / `callWithIfNestedFuncContext`: the
  extraArgs wrapper detection described above.
- `imports.readImportablePaths`: the discovery walk (exclusions, recursion,
  symlink and includibility rules).
- `imports.importAsAttrs`: discovery plus import into an attribute set.
- `imports.isDirectoryIncludible`, `imports.dirContainsNixFiles`:
  includibility checks.
- `imports.uniqueListToAttrs`: `listToAttrs` that reports name collisions
  instead of shadowing.
- `imports.stripNixSuffix`: the naming rule for discovered entries.

The set is built with `lib.makeExtensible`, so it can be extended via
`nix-utilities.lib.extend`.

## Caveats and pitfalls

- **One flake-parts instance.** The `flake-parts.follows` line in the
  getting-started snippet keeps a single flake-parts in play. nix-utilities
  imports the partitions module from its own `flake-parts` input; without
  the follows this still evaluates as long as nothing else imports
  `flakeModules.partitions`, but you are then running another revision's
  partition machinery inside your `mkFlake`, and the moment any other
  module imports `flakeModules.partitions` from your own flake-parts
  evaluation fails with "option `partitions` is already declared". The
  module system rejects duplicate option declarations even when the copies
  are identical; it only deduplicates imports of the same store path.
- **Top-level definitions of claimed attributes do not merge.** For
  attributes flake-parts declares options for (`packages`, `checks`,
  `devShells`, `formatter`, `apps`, `overlays`, `nixosConfigurations`,
  `nixosModules`) a top-level definition is silently discarded by the
  `mkForce` wiring. The freeform attributes (`homes`, `homeConfigurations`,
  `homeModules`, `flakeModules`, `nixosConfigurationExtras`,
  `homeConfigurationExtras`) take exactly one definition: the top-level
  definition and the partition's collide inside the partition evaluation,
  and reading the attribute fails with "definitions can't be merged
  automatically". Add content inside the partition instead.
- **dev claims coarsely.** `dev/` existing claims `checks`, `devShells` and
  `formatter` even for missing sub-directories, so module-contributed
  content survives - and so root-level definitions of those three are
  discarded whenever `dev/` exists.
- **Ellipsis-only wrappers are not detected.** The arity probe cannot
  distinguish `{ ... }: ...` from a module, so an extraArgs wrapper must
  either be a plain lambda (`extraArgs: ...`) or declare at least one named
  argument. A body that fails with something other than `throw`/`assert`
  while being probed aborts evaluation (see `callWithIfNestedFuncContext`
  in [lib/functions.nix](./lib/functions.nix)).
- **`callWith` passes only named arguments.** An ellipsis in a called
  file's pattern receives nothing extra: name every argument you want, the
  `...` is only tolerated.
- **Symlink semantics differ per Nix implementation.** Whether a dangling
  non-`.nix` symlink is dropped during discovery or reaches the inclusion
  probe depends on `pathExists` (upstream Nix follows links, Determinate
  Nix lstats them); the bundled probes tolerate both. `verifyFileType`
  accepts a symlink for both `"regular"` and `"directory"` - a wrong-kind
  target surfaces at use time.
- **Metadata files are special at the root only.** A `system-metadata.nix`
  or `home-metadata.nix` nested deeper in a tree is an ordinary file and
  gets imported as part of the module tree like any other.
- **`lib` is injected, not native.** `lib` is a module-system built-in, so
  it appears in neither `_module.args` nor `specialArgs`; nix-utilities
  injects it explicitly so discovered files can ask for it. In
  `callPackage`-style calls (packages, `dev/formatter.nix`) `pkgs` wins
  name collisions - `config` and `lib` keep their nixpkgs meaning there.

## Additional modules

### precommit-treefmt

`flakeModules.precommit-treefmt` (not imported automatically) wires
[git-hooks.nix](https://github.com/cachix/git-hooks.nix) and
[treefmt-nix](https://github.com/numtide/treefmt-nix) together with sane
defaults: the treefmt pre-commit hook runs the project's actual treefmt
wrapper, `nixfmt` runs in strict mode, and a `default` dev shell carrying
the pre-commit hook is added at `mkDefault` priority.

The consumer must import the `git-hooks.nix` and `treefmt-nix` flake
modules itself (they need their own inputs); this module only configures
them.
