{ lib, ... }:

let
  inherit (builtins) functionArgs isFunction mapAttrs;
in
rec {
  /**
    Calls a function with an attribute set of arguments, passing only the
    arguments the function expects.

    If the function takes no arguments (i.e. `functionArgs` returns `{ }`),
    the full `arguments` set is passed directly. If the function has named
    arguments, only the matching attributes are forwarded. Required arguments
    that are missing from `arguments` will throw an error. If `func` is not
    a function, it is returned as-is.

    # Inputs

    `func`
    : The function to call.

    `arguments`
    : An attribute set of arguments to select from.

    # Type

    ```
    callWith :: (AttrSet -> a) -> AttrSet -> a
    ```

    # Examples
    :::{.example}
    ## `nix-utils-lib.functions.callWith` usage example

    ```nix
    callWith ({ a, b }: a + b) { a = 1; b = 2; c = 3; }
    => 3

    callWith ({ a, b ? 10 }: a + b) { a = 5; }
    => 15

    callWith ({ a }: a) { }
    => error: callWith: argument `a` does not exist.

    callWith "not-a-function" { }
    => "not-a-function"
    ```

    :::
  */
  callWith =
    func: arguments:
    let
      funcArgs = functionArgs func;
    in
    if isFunction func then
      if funcArgs == { } then
        func arguments
      else
        func (
          mapAttrs (n: _: arguments.${n} or (throw "callWith: argument `${n}` does not exist.")) (
            lib.filterAttrs (name: hasDefault: builtins.hasAttr name arguments || !hasDefault) funcArgs
          )
        )
    else
      func;

  callWithIfNestedFunc =
    numLevels: func: arguments:
    let
      arity =
        f:
        if isFunction f then
          let
            args = functionArgs f;

            mockArg = builtins.listToAttrs (
              map (name: {
                inherit name;
                value = throw "peek";
              }) (builtins.attrNames args)
            );

            attempt = builtins.tryEval (f mockArg);
          in
          if attempt.success && isFunction attempt.value then 1 + arity attempt.value else 1
        else
          0;
    in
    if (arity func > numLevels) then callWith func arguments else func;
}
