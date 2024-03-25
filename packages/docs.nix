{
  inputs,
  lib,
  nixosOptionsDoc,
  nix-utils-lib,
  runCommand,
  ...
}:

with lib;
let
  inherit (inputs) self;

  eval =
    modules:
    evalModules {
      modules = modules ++ [ { _module.check = false; } ];

      specialArgs = {
        inherit nix-utils-lib;
      };
    };

  rev = self.rev or "main";

  transformOptions =
    opt:
    opt
    // {
      declarations = map (
        decl:
        let
          declStr = toString decl;
          subpath = concatStringsSep "/" (drop 4 (splitString "/" declStr));
        in
        {
          url = "https://gitlab.com/neodyme-labs/infrastructure/nix-utilities/-/blob/${rev}/${subpath}";
          name = subpath;
        }
      ) opt.declarations;

      # Explicitly ignore _module arguments (such as _module.args)
      visible = opt.visible && (!hasPrefix "_module." opt.name);
    };

  completeEval = eval (builtins.attrValues self.nixosModules);
  completeOptionsDoc = nixosOptionsDoc {
    inherit (completeEval) options;
    inherit transformOptions;
  };
in
runCommand "options-docs" { } ''
  mkdir $out

  cp ${completeOptionsDoc.optionsAsciiDoc} $out/options.adoc
  cp ${completeOptionsDoc.optionsCommonMark} $out/options.md
  cp ${completeOptionsDoc.optionsJSON}/share/doc/nixos/options.json $out/options.json

  ${concatStringsSep "\n" (
    mapAttrsToList (
      name: definition:
      let
        moduleEval = eval [ definition ];
        moduleOptionsDoc = nixosOptionsDoc {
          inherit (moduleEval) options;
          inherit transformOptions;
        };
      in
      ''
        mkdir -p "$out/modules/${name}"

        cp ${moduleOptionsDoc.optionsAsciiDoc} "$out/modules/${name}/options.adoc"
        cp ${moduleOptionsDoc.optionsCommonMark} "$out/modules/${name}/options.md"
        cp ${moduleOptionsDoc.optionsJSON}/share/doc/nixos/options.json "$out/modules/${name}/options.json"
      ''
    ) self.nixosModules
  )}
''
