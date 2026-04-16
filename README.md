# Nix Utilities

> [!IMPORTANT]
> This repository has been completely refactored. If you're using nix-utilities already you should consider migrating to `v2`. The main branch currently holds the legacy version, but this is subject to change. You can switch to the current version by using the `v2` branch.

nix-utilities is an opinionated module for structuring nix projects. It aims to reduce boilerplate by automatically importing files from defined paths, as well as minimise the nix evaluation by using [Flake Parts](https://flake.parts/).

If you're unfamiliar with flake-parts and flake partitions, feel free to check out their great documentation.

## Project Layout

```
# FIXME: Document and complete
<root>/             (* 1)
+-- apps/           (* 2, 3)
+-- dev/            (* 2, 4)
+-- flake-modules/  (* 2, 5)
+-- home-manager/   (* 2, 6)
+-- nixos/          (* 2, 7)
+-- overlays/       (* 2, 8)
+-- packages/       (* 2, 9)
```

- 1: Root of the tree that `nix-utilities` auto-imports. Configurable via `nixUtilities.root`.
- 2: Partition, see below for implementation details.
- 3: Default directory for the `apps` partition. Can be overridden.
- 4: Default directory for the `dev` partition. Can be overridden.
- 5: Default directory for the `flakeModules` partition. Can be overridden.
- 6: Default directory for the `homeManager` partition. Can be overridden.
- 7: Default directory for the `nixos` partition. Can be overridden.
- 8: Default directory for the `overlays` partition. Can be overridden.
- 9: Default directory for the `packages` partition. Can be overridden.

## Partitions

All partitions, including sub-partitions of our specific partition implementation, support the presence of a `flake.nix` with a `flake.lock` files. The inputs from the flake will be used and available within the (sub-)partition, should they be present.

All partition implementations (described below) can be overridden by providing a `flake-module.nix` file within the configured directory. If you do so those modules will be imported instead of our implementation.

For an example of how this can be useful refer to this repository's [dev](./dev/) directory.
## Provided Partitions

nix-utilities provides the following partitions:

### apps

Provided via flake: [`partition-apps`](./flake-modules/partition-apps.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the directory configured at `nixUtilities.paths.appsDirectory` and imports all nix files, except `flake.nix` and `flake-module.nix`, as well as all base-level directories, which include a `default.nix` file, exposing them through the flake-parts `perSystem.apps` interface.
For regular files, the `.nix` suffix is dropped.

The following arguments are passed:

- [flake-parts general module arguments](https://flake.parts/module-arguments#general-module-arguments)
- [flake-parts `perSystem` module arguments](https://flake.parts/module-arguments#persystem-module-parameters)
- the following [flake-parts `top` module arguments](https://flake.parts/module-arguments#top-level-module-arguments): `inputs`, `self`
- nix-utils-lib

### dev

Provided via flake: [`partition-dev`](./flake-modules/partition-dev.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the the two subdirectories `checks` and `shells` of the parent directory configured at `nixUtilities.paths.devDirectory` and imports all nix files, as well as all base-level directories, which include a `default.nix` file, exposing them though the flake-parts `perSystem.checks` and `perSystem.devShells` interface respectively.
For regular files, the `.nix` suffix is dropped.

The module also checks for the presence of `formatter.nix` and if present imports and calls it using `pkgs.callPackage` with the same additional arguments. The formatter is exposed through the flake-parts `perSystem.formatter` interface with a `lib.mkOverride` priority of `1001`, which is 1 less than `lib.mkDefault`, in order to allow overriding the value by other flake-modules such as [`treefmt-nix`](https://github.com/numtide/treefmt-nix).

The following arguments are passed:

- [flake-parts general module arguments](https://flake.parts/module-arguments#general-module-arguments)
- [flake-parts `perSystem` module arguments](https://flake.parts/module-arguments#persystem-module-parameters)
- the following [flake-parts `top` module arguments](https://flake.parts/module-arguments#top-level-module-arguments): `inputs`, `self`
- nix-utils-lib

### flakeModules

Provided via flake: [`partition-flakeModules`](./flake-modules/partition-flakeModules.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the directory configured at `nixUtilities.paths.flakeModulesDirectory` and imports all nix files, except `flake.nix` and `flake-module.nix`, as well as all base-level directories, which include a `default.nix` file, exposing them through the flake-parts `flake.flakeModules` interface.
For regular files, the `.nix` suffix is dropped.

The following extra arguments are passed, if the imported module is in the format `extraArgs: args: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

### homeManager

Provided via flake: [`partition-homeManager`](./flake-modules/partition-homeManager.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the the two subdirectories `modules` and `homes` of the parent directory configured at `nixUtilities.paths.homeManagerDirectory`.

For modules it imports all nix files exposing them directly though the flake-parts `flake.homeModules` interface, for any directory encountered at the base-level a new sub-partition is created and the attributes included from that partitions `homeModule` output. If the directory contains a `flake-module.nix` our implementation of the sub-partition can be overridden, otherwise `homeManager-module` is used. In either case the sub-partition module receives the path to the module base directory via an injected argument called `homeModulePath`, as well as the name of the module via an injected argument called `homeModuleName`.
For regular files, the `.nix` suffix is dropped.

The following extra arguments are passed to regular file modules, if they are in the format `extraArgs: args: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

For homes it imports all nix files exposing them directly though the flake-parts `flake.homeConfigurations` interface, for any directory encountered at the base-level a new sub-partition is created and the attributes included from that partitions `homeConfiguration` output. If the directory contains a `flake-module.nix` our implementation of the sub-partition can be overridden, otherwise `homeManager-home` is used. In either case the sub-partition module receives the path to the module base directory via an injected argument called `homeConfigurationPath`, as well as the name of the module via an injected argument called `homeConfigurationName`.
For regular files, the `.nix` suffix is dropped.

The following extra arguments are passed to regular file homes, if they are in the format `extraArgs: args: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

### homeManager-module

Provided via flake: [`partition-homeManager-module`](./flake-modules/partition-homeManager-module.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the directory configured by the `homeModulePath` module argument and imports all nix files, except `flake.nix` and `flake-module.nix`, as well as all base-level directories, which include a `default.nix` file, exposing them through the flake-parts `flake.homeModule` interface.

The following extra arguments are passed to modules, if they are in the format `extraArgs: args: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

### homeManager-home

Provided via flake: [`partition-homeManager-home`](./flake-modules/partition-homeManager-home.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the directory configured by the `homeConfigurationPath` module argument and imports all nix files, except `flake.nix` and `flake-module.nix`, as well as all base-level directories, which include a `default.nix` file, exposing them through the flake-parts `flake.homeConfiguration` interface.

The following extra arguments are passed to homes, if they are in the format `extraArgs: args: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

### nixos

Provided via flake: [`partition-nixos`](./flake-modules/partition-nixos.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the the two subdirectories `modules` and `systems` of the parent directory configured at `nixUtilities.paths.nixosDirectory`.

For modules it imports all nix files exposing them directly though the flake-parts `flake.nixosModules` interface, for any directory encountered at the base-level a new sub-partition is created and the attributes included from that partitions `nixosModule` output. If the directory contains a `flake-module.nix` our implementation of the sub-partition can be overridden, otherwise `nixos-module` is used. In either case the sub-partition module receives the path to the module base directory via an injected argument called `nixosModulePath`, as well as the name of the module via an injected argument called `nixosModuleName`.
For regular files, the `.nix` suffix is dropped.

The following extra arguments are passed to regular file modules, if they are in the format `extraArgs: args: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

For systems it recursively searches for valid system directories (directories containing a `system-metadata.nix` file) and creates a new sub-partition for it, exposing the `nixosConfiguration` output of the sub-partition via the `flake.nixosConfigurations` interface. Should the directory contain a `flake-module.nix` it is imported, otherwise our `nixos-systems` implementation is used. In either case the sub-partition module receives the path to the system base directory via an injected argument called `nixosConfigurationPath`, as well as the name of the configuration via an injected argument called `nixosConfigurationName`.
The name of the output is the inverted directory structure with `/` replaced by a `.`.

### nixos-module

Provided via flake: [`partition-nixos-module`](./flake-modules/partition-nixos-module.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the directory configured by the `nixosModulePath` module argument and imports all nix files, except `flake.nix` and `flake-module.nix`, as well as all base-level directories, which include a `default.nix` file, exposing them through the flake-parts `flake.nixosModule` interface.

The following extra arguments are passed to modules, if they are in the format `extraArgs: args: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

### nixos-system

Provided via flake: [`partition-nixos-system`](./flake-modules/partition-nixos-system.nix) \
Automatically imported: Yes, if not overridden

This module reads the metadata of the system from the `system-metadata.nix` file contained in the directory configured using the `nixosConfigurationPath` module argument. If the metadata is a function it will be called with the following arguments:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

Using the metadata a new configuration is created through the `lib.nixosSystem` function of `nixpkgs`. Any metadata-supplied modules and overlays are applied.
The module also includes either the `default.nix` file, should it be present, or recursively finds all  nix files (traversing non-includible directories) and includible directories. Base-level files with the names `flake.nix`, `flake-module.nix`, and `system-metadata.nix` will be ignored.

The metadata is structured as follows:

| Attribute      | Optional | Usage                                                         |
| -------------- | -------- | ------------------------------------------------------------- |
| `hostPlatform` | No       | Platform (system) of the configuration.                       |
| `modules`      | Yes      | List of modules included in the configuration.                |
| `nixpkgs`      | Yes      | The nixpkgs flake being used. Falls back to `inputs.nixpkgs`. |
| `overlays`     | Yes      | List of overlays applied to the nixpkgs.                      |

The following extra arguments are passed to modules, if they are in the format `extraArgs: args: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

### overlays

Provided via flake: [`partition-overlays`](./flake-modules/partition-overlays.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the directory configured at `nixUtilities.paths.overlaysDirectory` and imports all nix files, except `flake.nix` and `flake-module.nix`. Encountered base-level directories are treated as sub-partitions. If a `flake-module.nix` file is present, then this overrides our implementation, otherwise the `overlays-overlay` partition will be included. In either case the sub-partition module receives the path to the overlay base directory via an injected argument called `overlayPath`, as well as the name of the overlay via an injected argument called `overlayName`. The `overlay` output of the sub-partition will be used.
All discovered overlays are exposed through the flake-parts `overlays` interface.
For regular files, the `.nix` suffix is dropped.

The following extra arguments are passed to regular file overlays, if they are in the format `extraArgs: final: prev: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

### overlays-overlay

Provided via flake: [`partition-overlays-overlay`](./flake-modules/partition-overlays-overlay.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the directory configured via the module argument `overlayPath`. The output `overlay` will be set to either the imported `default.nix` file, if present, or an overlay with attributes based on all discovered base-level nix files and includible directories.
For regular files, the `.nix` suffix is dropped.

The following extra arguments are passed to overlay parts, if they are in the format `extraArgs: final: prev: { ... }`:

- [flake-parts _module.args](https://flake.parts/module-arguments#module-arguments)
- [flake-parts _module.specialArgs](https://flake.parts/module-arguments#module-arguments)
- nix-utils-lib

### packages

Provided via flake: [`partition-packages`](./flake-modules/partition-packages.nix) \
Automatically imported: Yes, if not overridden

This module iterates over the directory configured at `nixUtilities.paths.pkgsDirectory` and imports all nix files, except `flake.nix` and `flake-module.nix`, as well as all base-level directories, which include a `default.nix` file, exposing them through the flake-parts `perSystem.packages` interface.
For regular files, the `.nix` suffix is dropped.

The following additional arguments are passed to `pkgs.callPackage`:

- [flake-parts general module arguments](https://flake.parts/module-arguments#general-module-arguments)
- [flake-parts `perSystem` module arguments](https://flake.parts/module-arguments#persystem-module-parameters)
- the following [flake-parts `top` module arguments](https://flake.parts/module-arguments#top-level-module-arguments): `inputs`, `self`
- nix-utils-lib

## Additional modules

The following additional modules are provided:

### precommit-treefmt

Provided via flake: [`precommit-treefmt`](./flake-modules/precommit-treefmt.nix) \
Automatically imported: No

This module configures default value for [`git-hooks.nix`](https://github.com/cachix/git-hooks.nix) and [`treefmt-nix`](https://github.com/numtide/treefmt-nix).

For git-hooks it enables the `nixfmt` hook with an argument added for strict mode.

For treefmt it enables the `nixfmt` formatter in strict mode.

Additionally a `default` shell is added with `mkDefault` priority. This shell includes the pre-commit shell hook.
