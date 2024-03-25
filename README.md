# Nix Utilities

This repository aims to provide functionality that makes writing NixOS configurations more pleasant and readable.
It can also be used to reduce boilerplate in any other repository using nix flakes.

This repository uses [Flake Parts](https://flake.parts/), if you're unfamiliar with them feel free to check out their
documentation.

## Project Layout

In order to reduce boilerplate this module will import all files according to a standard directory structure.
The whole structure is configurable but works as follows:

```
( 1) root
+-- ( 2) apps             - Flake apps
+-- ( 3) checks           - Flake checks
+-- home-manager
|   +-- ( 4) default-home - home-manager default home
|   +-- ( 5) homes        - home-manager homes
|   +-- ( 6) modules      - home-manager modules
+-- nixos
|   +-- ( 7) modules      - NixOS modules
|   +-- ( 8) systems      - NixOS configurations
+-- ( 9) nixpkgs-config   - Nixpkgs config
+-- (10) overlays         - Overlays
+-- (11) packages         - Flake packages
+-- (12) shells           - Flake devShells
```

- (1) The root from which to search.
  Configurable using `nixUtilities.root` (e.g. `./.` or `./nix`)

- The directories (2), (3), (11) and (12) are called using a `pkgs.callPackage` style.
  This means that a mapping of _name of `.nix` file_ or _name of importable directory_ to the called path will be
  created. The result will be exposed as the specified flake output.
  The above list displays the default values, but they are configurable using the following options:

  - ( 2) `nixUtilities.paths.appsDirectory`
  - ( 3) `nixUtilities.paths.checksDirectory`
  - (11) `nixUtilities.paths.pkgsDirectory`
  - (12) `nixUtilities.paths.shellsDirectory`

- The directories (4), (5) and (6) are related to home-manager rather than pure flake outputs.
  The home configurations/modules are exposed (not built) using the widely spread flake outputs of:

  - (4) `homeConfigurations.default` (forcefully replaces home named `default`)
  - (5) `homeConfigurations`
  - (5) `homeModules`
    The above list displays the default values, but they are configurable using the following options:
  - (4) `nixUtilities.paths.hmDefaultConfigDirectory`
  - (5) `nixUtilities.paths.hmConfigDirectory`
  - (6) `nixUtilities.paths.hmModulesDirectory`

- The directories (7) and (8) are related to nixos rather than pure flake outputs.
  The configurations/modules are exposed (not built) using the widely spread flake outputs of:

  - (7) `nixosModules`
  - (8) `nixosConfigurations`

  The above list displays the default values, but they are configurable using the following options:

  - (7) `nixUtilities.paths.nixosModulesDirectory`
  - (8) `nixUtilities.paths.nixosConfigDirectory`

- The directory (9) contains the nixpkgs config, this will be applied to all flake outputs, as well as built
  `nixosConfiguration`s.
  The paths can be configured using the option `nixUtilities.paths.nixpkgsConfigDirectory`.

- The directory (10) contains overlays. These are imported somewhat similar to (2), but are not called, just imported
  and passed extra arguments, such as `inputs`, `lib`, `nix-utils-lib` and `self`.

## Example

You can find an example flake under [example](./example).
