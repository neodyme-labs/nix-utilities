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
          hooks.treefmt = {
            enable = true;
            # The stock hook runs a bare treefmt without the project's config
            # or formatters; substitute the treefmt-nix wrapper, which
            # carries both.
            packageOverrides.treefmt = config.treefmt.build.wrapper;
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
