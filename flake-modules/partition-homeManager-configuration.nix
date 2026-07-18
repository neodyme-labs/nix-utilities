{ nix-utils-lib, ... }:
{
  config,
  inputs,
  homeConfigurationName,
  homeConfigurationPath,
  ...
}:

let
  defaultNix = homeConfigurationPath + "/default.nix";
  metadataFile = homeConfigurationPath + "/home-metadata.nix";

  extraArgs = config._module.args // config._module.specialArgs // { inherit nix-utils-lib; };

  metadata =
    let
      content = nix-utils-lib.callWithContext (toString metadataFile) (import metadataFile) extraArgs;
    in
    {
      inherit (content) hostPlatform;

      home-manager = content.home-manager or inputs.home-manager;
      nixpkgs = content.nixpkgs or inputs.nixpkgs;
      # nixpkgs config (allowUnfree, ...): unlike a NixOS system, a home
      # configuration imports its package set directly, so modules have no
      # `nixpkgs.config` to set it through.
      config = content.config or { };
      modules = content.modules or [ ];
      overlays = content.overlays or [ ];
      extraSpecialArgs = content.extraSpecialArgs or { };

      # Arbitrary, non-module-system facts readable without forcing the
      # build - see `homeConfigurationExtras` in partition-homeManager.nix.
      extra = content.extra or { };
    };

  # The configuration's own module tree: default.nix if present, otherwise
  # all discovered nix files and includible directories. Homes from homes/
  # are never pulled in implicitly - name them in the metadata's `modules`
  # (e.g. `{ self, ... }: { modules = [ self.homes.alice ]; }`).
  configurationModule =
    if nix-utils-lib.verifyFileType "regular" defaultNix then
      nix-utils-lib.callWithIfNestedFuncContext (toString defaultNix) 1 (import defaultNix) extraArgs
    else
      {
        imports =
          map
            ({ path, ... }: nix-utils-lib.callWithIfNestedFuncContext (toString path) 1 (import path) extraArgs)
            (
              nix-utils-lib.readImportablePaths {
                dir = homeConfigurationPath;

                # Metadata is special at the configuration root only.
                excludeTopLevel = [
                  "flake.nix"
                  "flake-module.nix"
                  "home-metadata.nix"
                ];

                recursive = true;
              }
            );
      };
in
{
  flake = {
    # Exposed separately from `homeConfiguration` so reading it never
    # forces the home's module tree. Singular next to the singular
    # `homeConfiguration`; the aggregate output is the plural
    # `homeConfigurationExtras`, so the two definitions never collide.
    homeConfigurationExtra = metadata.extra;

    homeConfiguration = metadata.home-manager.lib.homeManagerConfiguration {
      pkgs = import metadata.nixpkgs {
        system = metadata.hostPlatform;
        inherit (metadata) config overlays;
      };

      modules = [
        configurationModule
        {
          _module.args = {
            inherit homeConfigurationName homeConfigurationPath;
            homeConfigurationExtra = metadata.extra;
          };
        }
      ]
      ++ metadata.modules;

      # `hostInputs` mirrors the NixOS systems partition: this
      # configuration's own fully-resolved inputs (root inputs merged with
      # its extraInputsFlake, if any), distinct from a module's eagerly
      # resolved `inputs`.
      extraSpecialArgs = {
        hostInputs = inputs;
      }
      // metadata.extraSpecialArgs;
    };
  };
}
