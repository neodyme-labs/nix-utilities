{ inputs, self, ... }:

{
  imports = with inputs; [
    git-hooks.flakeModule
    treefmt-nix.flakeModule

    self.flakeModules.partition-dev
    self.flakeModules.precommit-treefmt
  ];

  perSystem = {
    treefmt = {
      programs = {
        mdformat = {
          enable = true;

          plugins =
            ps: with ps; [
              mdformat-frontmatter
              mdformat-gfm
            ];

          settings.number = true;
        };

        statix.enable = true;
      };

      # Check fixtures are data: formatting or statix-fixing them changes
      # what the tests test (e.g. { ... } vs _ probe differently).
      settings.global.excludes = [ "dev/checks/fixtures/**" ];
    };
  };
}
