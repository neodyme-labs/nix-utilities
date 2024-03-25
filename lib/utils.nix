{ lib }:

with lib;
let
  # * Shorthand for creating a submodule option
  mkSubmodule =
    with types;
    {
      config ? { },
      default ? { },
      description ? "",
      options ? { },
      wrapper ? id,
    }:
    let
      config' = config;
      options' = options;
    in
    mkOption {
      type =
        with types;
        wrapper (
          submodule (
            # We are required to explicitly put config, name and options into the arguments, due to the way they are handled
            {
              config,
              name ? null,
              options,
              ...
            }@args:
            let
              cfg = if builtins.isFunction config' then config' args else config';
              opt = if builtins.isFunction options' then options' args else options';
            in
            {
              config = cfg;
              options = opt;
            }
          )
        );
      inherit default description;
    };

  # * Shorthand for extending a submodule option
  mkSubmoduleExtension' =
    with types;
    wrapper: args:
    mkOption {
      type =
        with types;
        wrapper (
          submodule (
            # We are required to explicitly put config, name and options into the arguments, due to the way they are handled
            {
              config,
              name ? null,
              options,
              ...
            }@args':
            let
              eval = if builtins.isFunction args then args args' else args;

              config = if (eval ? config) then eval.config else { };
              options =
                if (eval ? config) || (eval ? options) then
                  if (eval ? options) then eval.options else { }
                else
                  eval;
            in
            {
              inherit config options;
            }
          )
        );
    };

  mkSubmoduleExtension = mkSubmoduleExtension' id;

  presets = with types; {
    "List" = {
      wrapper = listOf;
      default = [ ];
    };

    "Attrs" = {
      wrapper = attrsOf;
      default = { };
    };
  };
in
{
  inherit mkSubmodule mkSubmoduleExtension' mkSubmoduleExtension;
}
// concatMapAttrs (name: config: {
  "mk${name}Submodule" = args: mkSubmodule (args // config);
  "mk${name}SubmoduleExtension" = mkSubmoduleExtension' config.wrapper;
}) presets
