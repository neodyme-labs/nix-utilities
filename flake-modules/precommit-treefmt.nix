_:

{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      devShells.default = lib.mkDefault (
        pkgs.mkShell {
          shellHook = ''
            ${config.pre-commit.shellHook}
          '';
        }
      );

      pre-commit = {
        inherit pkgs;

        settings = {
          hooks.nixfmt = {
            enable = true;
            args = [ "--strict" ];
          };
        };
      };

      treefmt = {
        programs = {
          nixfmt = {
            enable = true;
            strict = true;
          };
        };
      };
    };
}
