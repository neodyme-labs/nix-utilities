{ nix-utils-lib, ... }:
{
  config,
  inputs,
  lib,
  options,
  self,
  ...
}@top:

with lib;
with nix-utils-lib;
with builtins;
let
  cfg = config.nixUtilities;

  mkDirectoryOption =
    {
      defaultPath,
      description ? defaultPath,
    }:
    mkOption {
      type = with types; nullOr path;
      default = if cfg.root != null then "${cfg.root}/${defaultPath}" else null;
      defaultText = "`\${nixUtilities.root}/${defaultPath}` or `null` if `nixUtilities.root` is `null`";
      description = "The path for ${description}.";
    };

  mkFeatureOption = name: mkEnableOption "the ${name} feature" // { default = true; };

  fileExists = path: path != null && pathExists path && readFileType path == "regular";
  directoryExists = path: path != null && pathExists path && readFileType path == "directory";

  processDir = apply: path: mapAttrs (_: apply) (imports.allAsAttrs' { excludeTopLevel = [ ]; } path);

  importDir' =
    extra:
    processDir (
      v:
      import v (
        cfg.specialArgs
        // {
          inherit
            inputs
            lib
            nix-utils-lib
            self
            ;
        }
        // extra
      )
    );
  callDir' =
    pkgs: extra:
    processDir (
      v:
      pkgs.callPackage v (
        cfg.specialArgs
        // {
          inherit
            inputs
            lib
            nix-utils-lib
            self
            ;
        }
        // extra
      )
    );

  getSystemMetadata =
    name: configBase:
    let
      systemCfg = cfg.nixos.hosts.${name};
      systemMetadataFile = "${configBase}/${systemCfg.metadataFilename}";
      systemMetadata =
        if systemCfg.metadataFilename != null && fileExists systemMetadataFile then
          import systemMetadataFile
        else
          { };

      getMetadata = name: systemMetadata.${name} or systemCfg.${name};
      getMetadata' = default: name: systemMetadata.${name} or systemCfg.${name} or default;

      importedModules = getMetadata "importedModules";
      importedOverlays = getMetadata "importedOverlays";
    in
    rec {
      inherit name configBase;
      inherit (cfg.versions.${version}) nixpkgs;

      versionedInputs = cfg.versions.${version}.extraInputs;

      modules =
        (
          if getMetadata "importAllModules" then
            attrValues (self.nixosModules or { })
          else
            attrValues (filterAttrs (name: _: elem name importedModules) (self.nixosModules or { }))
        )
        ++ getMetadata "inlineModules";
      overlays =
        if getMetadata "importAllOverlays" then
          attrValues self.overlays
        else
          attrValues (filterAttrs (name: _: elem name importedOverlays) self.overlays);

      homeManager = if getMetadata "addHomeManager" then cfg.versions.${version}.home-manager else null;

      addUtilsLib = getMetadata "addUtilsLib";
      localSystem = getMetadata' null "localSystem";
      nixpkgsConfig = getMetadata' { } "nixpkgsConfig";
      setFQDN = getMetadata "setFQDN";
      system = getMetadata "system";
      version = getMetadata "version";
    };

  getHomeMetadata =
    username: configBase:
    let
      homeCfg = cfg.home.homes.${username};
      homeMetadataFile = "${configBase}/${homeCfg.metadataFilename}";
      homeMetadata =
        if homeCfg.metadataFilename != null && fileExists homeMetadataFile then
          import homeMetadataFile
        else
          { };

      getMetadata = name: homeMetadata.${name} or homeCfg.${name};

      importedModules = getMetadata "importedModules";
      importedOverlays = getMetadata "importedOverlays";
    in
    rec {
      inherit configBase;
      defaultHome =
        if directoryExists cfg.paths.hmDefaultConfigDirectory then
          cfg.paths.hmDefaultConfigDirectory
        else
          { };

      modules =
        optional (getMetadata "importDefaultHome") defaultHome
        ++ (
          if getMetadata "importAllModules" then
            attrValues (self.homeModules or { })
          else
            attrValues (filterAttrs (name: _: elem name importedModules) (self.homeModules or { }))
        )
        ++ getMetadata "inlineModules";
    };

  buildNixosConfigurations =
    baseDir:
    mapAttrs
      (
        name: systemBase:
        let
          systemMetadata = getSystemMetadata name systemBase;

          importNixpkgs =
            flake:
            import flake (
              {
                inherit (systemMetadata) overlays;

                config =
                  optionalAttrs (directoryExists cfg.paths.nixpkgsConfigDirectory) (
                    import cfg.paths.nixpkgsConfigDirectory {
                      inherit (systemMetadata.nixpkgs) lib;
                      inherit nix-utils-lib;
                    }
                  )
                  // systemMetadata.nixpkgsConfig;
              }
              // (
                if systemMetadata.localSystem != null then
                  { inherit (systemMetadata) localSystem; }
                else
                  { inherit (systemMetadata) system; }
              )
            );

          pkgs = importNixpkgs systemMetadata.nixpkgs;

          args =
            cfg.nixos.specialArgs
            // {
              inherit inputs self systemMetadata;
              inherit (systemMetadata) system versionedInputs;

              nixpkgs = mapAttrs (_: v: importNixpkgs v.nixpkgs) cfg.versions;
            }
            // optionalAttrs systemMetadata.addUtilsLib { inherit nix-utils-lib; };
        in
        systemMetadata.nixpkgs.lib.nixosSystem {
          inherit pkgs;

          modules =
            systemMetadata.modules
            ++ [
              {
                config = {
                  networking = optionalAttrs systemMetadata.setFQDN {
                    hostName = head (splitString "." systemMetadata.name);
                    domain = concatStringsSep "." (tail (splitString "." systemMetadata.name));
                  };

                  nix = {
                    nixPath = [ "nixpkgs=${systemMetadata.nixpkgs}" ];

                    registry = {
                      nixpkgs.flake = systemMetadata.nixpkgs;
                    };
                  };
                };
              }
              (import systemBase)
            ]
            ++ optionals (systemMetadata.homeManager != null) [
              systemMetadata.homeManager.nixosModules.home-manager
              {
                config = {
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;

                    extraSpecialArgs = args;
                  };

                  nix = {
                    nixPath = [ "home-manager=${systemMetadata.homeManager}" ];

                    registry = {
                      home-manager.flake = systemMetadata.homeManager;
                    };
                  };

                  nixpkgs.hostPlatform = systemMetadata.system;
                };
              }
            ];

          specialArgs = args;
        }
      )
      (
        imports.directoriesAsAttrsRecursive' {
          pathSeparator = ".";
          pathNameReverseOrder = true;
        } baseDir
      );

  buildHomeConfigurations =
    baseDir:
    mapAttrs (
      username: homeDir:
      let
        homeMetadata = getHomeMetadata username homeDir;
      in
      {
        imports = homeMetadata.modules ++ [
          {
            config._module.args = {
              inherit homeMetadata;
            };
          }
          (import homeDir)
        ];
      }
    ) (imports.allAsAttrs baseDir)
    // optionalAttrs (directoryExists cfg.paths.hmDefaultConfigDirectory) {
      default = import cfg.paths.hmDefaultConfigDirectory;
    };
in
{
  options = {
    nixUtilities = {
      root = mkOption {
        type = with types; nullOr path;
        default = null;
        description = "Base path used for default paths.";
      };

      features = {
        pre-commit-hooks = mkFeatureOption "pre-commit-hooks";
        treefmt = mkFeatureOption "treefmt";
      };

      nixpkgs = mkOption {
        type = types.package;
        description = "Nixpkgs to use.";
      };

      specialArgs = mkOption {
        type = types.attrs;
        default = { };
        description = "Extra arguments passed to all automatically imported files.";
      };

      exportedOverlayPackages = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = "Packages to export after importing all overlays.";
      };

      paths = {
        appsDirectory = mkDirectoryOption {
          defaultPath = "apps";
        };

        checksDirectory = mkDirectoryOption {
          defaultPath = "checks";
        };

        hmConfigDirectory = mkDirectoryOption {
          defaultPath = "home-manager/homes";
          description = "home-manager homes";
        };

        hmDefaultConfigDirectory = mkDirectoryOption {
          defaultPath = "home-manager/default-home";
          description = "home-manager default home";
        };

        hmModulesDirectory = mkDirectoryOption {
          defaultPath = "home-manager/modules";
          description = "home-manager modules";
        };

        nixosConfigDirectory = mkDirectoryOption {
          defaultPath = "nixos/systems";
          description = "NixOS configurations";
        };

        nixosModulesDirectory = mkDirectoryOption {
          defaultPath = "nixos/modules";
          description = "NixOS modules";
        };

        nixpkgsConfigDirectory = mkDirectoryOption {
          defaultPath = "nixpkgs-config";
          description = "nixpkgs configuration";
        };

        overlaysDirectory = mkDirectoryOption {
          defaultPath = "overlays";
        };

        pkgsDirectory = mkDirectoryOption {
          defaultPath = "packages";
        };

        shellsDirectory = mkDirectoryOption {
          defaultPath = "shells";
        };
      };

      nixos = {
        hosts = mkOption {
          type =
            with types;
            lazyAttrsOf (submodule {
              options =
                # Inherit options
                concatMapAttrs (name: opt: {
                  ${name} = mkOption {
                    inherit (opt) description type;

                    default = cfg.nixos.defaults.${name};
                    defaultText = literalExpression "nixUtilities.nixos.defaults.${name}";
                  };
                }) options.nixUtilities.nixos.defaults
                # Extend with options that need to be set on a per-system basis
                // {
                  system = mkOption {
                    type = str;
                    description = "The system for which to build. Must be set either here or in the metadata file.";
                  };
                };
            });

          default = { };
          description = "Per-host settings.";
        };

        specialArgs = mkOption {
          type = types.attrs;
          default = { };
          description = "Extra arguments passed to all nixos configurations.";
        };

        defaults = {
          addHomeManager = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to add home-manager, should it be specified.";
          };

          addUtilsLib = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to inject the nix-utils-lib into module arguments.";
          };

          importAllModules = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to import all flake-defined modules by default.";
          };

          importAllOverlays = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to import all flake-defined overlays by default.";
          };

          importedModules = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = "List of flake-defined NixOS modules imported by all configurations.";
          };

          importedOverlays = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = "List of flake-defined NixOS overlays imported by all configurations.";
          };

          inlineModules = mkOption {
            type = with types; listOf deferredModule;
            default = [ ];
            description = "Inline modules imported by all configurations.";
          };

          metadataFilename = mkOption {
            type = with types; nullOr str;
            default = "system-metadata.nix";
            description = ''
              File from which to read the system metadata (such as additional module imports, etc) from within the systems config directory.
              You can disable this feature by setting this value to `null`.
            '';
          };

          setFQDN = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to set the host fqdn according to configuration name.";
          };

          version = mkOption {
            type = types.str;
            description = ''
              Default version used by components, such as nixos, if the system doesn't set its version explicitly.
            '';
          };
        };
      };

      home = {
        homes = mkOption {
          type =
            with types;
            lazyAttrsOf (submodule {
              options =
                # Inherit options
                concatMapAttrs (name: opt: {
                  ${name} = mkOption {
                    inherit (opt) description type;

                    default = cfg.home.defaults.${name};
                    defaultText = literalExpression "nixUtilities.home.defaults.${name}";
                  };
                }) options.nixUtilities.home.defaults;
            });

          default = { };
          description = "Per-home settings.";
        };

        defaults = {
          importDefaultHome = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to import all the default home (if configured) by default.";
          };

          importAllModules = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to import all flake-defined modules by default.";
          };

          importedModules = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = "List of home-manager modules imported by all configurations.";
          };

          inlineModules = mkOption {
            type = with types; listOf deferredModule;
            default = [ ];
            description = "Inline modules imported by all configurations.";
          };

          metadataFilename = mkOption {
            type = with types; nullOr str;
            default = "home-metadata.nix";
            description = ''
              File from which to read the home metadata (such as additional module imports, etc) from within the home config directory.
              You can disable this feature by setting this value to `null`.
            '';
          };
        };
      };

      versions = mkOption {
        type =
          with types;
          lazyAttrsOf (submodule {
            options = {
              nixpkgs = mkOption {
                type = package;
                description = "nixpkgs flake input with the specified version.";
              };

              home-manager = mkOption {
                type = nullOr package;
                default = null;
                description = "home-manager flake input with the specified version.";
              };

              extraInputs = mkOption {
                type = lazyAttrsOf package;
                default = { };
                description = "Additional versioned flake inputs, will be passed as `versionedInputs`.";
              };
            };
          });

        default = { };
        description = "Version to flake input name mapping of components.";
      };
    };
  };

  config = {
    # Apply defaults
    nixUtilities = {
      nixpkgs = mkDefault (
        builtins.seq (inputs.nixpkgs
          or (throw "nix-utilities: The flake does not have a `nixpkgs` input. Please configure `nixUtilities.nixpkgs`.")
        ) inputs.nixpkgs
      );

      nixos.hosts = mapAttrs (_: _: { }) (
        optionalAttrs (directoryExists cfg.paths.nixosConfigDirectory) (
          imports.directoriesAsAttrsRecursive' {
            pathSeparator = ".";
            pathNameReverseOrder = true;
          } cfg.paths.nixosConfigDirectory
        )
      );

      home.homes = mapAttrs (_: _: { }) (
        optionalAttrs (directoryExists cfg.paths.hmConfigDirectory) (
          imports.allAsAttrs cfg.paths.hmConfigDirectory
        )
      );
    };

    flake = mergeAttrsList (flatten [
      (optional (directoryExists cfg.paths.hmConfigDirectory) {
        homeConfigurations = buildHomeConfigurations cfg.paths.hmConfigDirectory;
      })

      (optional (directoryExists cfg.paths.hmModulesDirectory) {
        homeModules = imports.allAsAttrs cfg.paths.hmModulesDirectory;
      })

      (optional (directoryExists cfg.paths.nixosConfigDirectory) {
        nixosConfigurations = buildNixosConfigurations cfg.paths.nixosConfigDirectory;
      })

      (optional (directoryExists cfg.paths.nixosModulesDirectory) {
        nixosModules = imports.allAsAttrs cfg.paths.nixosModulesDirectory;
      })

      (optional (directoryExists cfg.paths.overlaysDirectory) {
        overlays = importDir' { } cfg.paths.overlaysDirectory;
      })
    ]);

    perSystem =
      {
        config,
        options,
        overlayPkgs,
        pkgs,
        self',
        system,
        ...
      }@perSystem:
      let
        callDir = callDir' pkgs { inherit perSystem pkgs top; };
        importDir = importDir' { inherit perSystem pkgs top; };
      in
      {
        config = mergeAttrsList (flatten [
          (optional (cfg.nixpkgs != null) {
            _module.args = {
              pkgs = import cfg.nixpkgs {
                inherit system;

                config = optionalAttrs (directoryExists cfg.paths.nixpkgsConfigDirectory) (
                  import cfg.paths.nixpkgsConfigDirectory {
                    inherit (cfg.nixpkgs) lib;
                    inherit nix-utils-lib;
                  }
                );
              };

              overlayPkgs = import cfg.nixpkgs {
                inherit system;

                config = optionalAttrs (directoryExists cfg.paths.nixpkgsConfigDirectory) (
                  import cfg.paths.nixpkgsConfigDirectory {
                    inherit (cfg.nixpkgs) lib;
                    inherit nix-utils-lib;
                  }
                );

                overlays = attrValues self.overlays;
              };
            };
          })

          (optional (directoryExists cfg.paths.appsDirectory) { apps = importDir cfg.paths.appsDirectory; })
          (optional (directoryExists cfg.paths.checksDirectory) {
            checks = callDir cfg.paths.checksDirectory;
          })

          {
            packages =
              listToAttrs (
                map (name: {
                  inherit name;
                  value = overlayPkgs.${name};
                }) cfg.exportedOverlayPackages
              )
              // optionalAttrs (directoryExists cfg.paths.pkgsDirectory) (callDir cfg.paths.pkgsDirectory);
          }

          (optional (cfg.features.pre-commit-hooks && options ? "pre-commit") {
            pre-commit = {
              check.enable = mkDefault true;

              settings.hooks = optionalAttrs (options ? "treefmt") { treefmt.enable = mkDefault true; };
            };

            # Expose the shell just containing the pre-commit hooks, if no other shell has been defined
            devShells.default = mkDefault config.pre-commit.devShell;
          })
          (optional (cfg.features.treefmt && options ? "treefmt") {
            treefmt = {
              programs = {
                nixfmt = {
                  enable = mkDefault true;
                  package = mkDefault pkgs.nixfmt-rfc-style;
                };

                statix.enable = mkDefault true;
              };
            };
          })

          # Override previous default shell if applicable
          (optional (directoryExists cfg.paths.shellsDirectory) {
            devShells = callDir cfg.paths.shellsDirectory;
          })
        ]);
      };
  };
}
