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
      eval = mockEval' numLevels func;
    in
    if (isFunction func && eval.success && isFunction eval.value) then
      callWith func arguments
    else
      func;

  mockCall' =
    count: func:
    if count > 0 && isFunction func then
      mockCall' (count - 1) (
        func (mapAttrs (_: _: null) (lib.filterAttrs (_: hasDefault: !hasDefault) (functionArgs func)))
      )
    else
      func;

  mockCall = mockCall' 1;

  mockEval' = count: func: builtins.tryEval (mockCall' count func);

  mockEval = mockEval' 1;
}
