{ lib }@args:

with lib;
with builtins;
let
  excluded = [ "default.nix" ];
in
mapAttrs' (name: type: {
  name = if type == "regular" then removeSuffix ".nix" name else name;
  value = import (./. + "/${name}") args;
}) (filterAttrs (name: _: !elem name excluded) (readDir ./.))
