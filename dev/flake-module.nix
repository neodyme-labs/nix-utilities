{ inputs, self, ... }:

{
  imports = with inputs; [
    git-hooks.flakeModule
    treefmt-nix.flakeModule

    self.flakeModules.partition-dev
    self.flakeModules.precommit-treefmt
  ];
}
