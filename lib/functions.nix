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
    that are missing from `arguments` will throw an error, mentioning
    `context` (usually the path of the file the function came from) when it
    is not `null`. If `func` is not a function, it is returned as-is.

    `callWith` is this function with a `null` context.

    # Inputs

    `context`
    : Description of the call site woven into error messages, or `null`.

    `func`
    : The function to call.

    `arguments`
    : An attribute set of arguments to select from.

    # Type

    ```
    callWithContext :: (String | Null) -> (AttrSet -> a) -> AttrSet -> a
    ```

    # Examples
    :::{.example}
    ## `nix-utils-lib.functions.callWithContext` usage example

    ```nix
    callWithContext "./example.nix" ({ a }: a) { }
    => error: callWith: argument `a` does not exist (while calling ./example.nix).
    ```

    :::
  */
  callWithContext =
    context: func: arguments:
    let
      funcArgs = functionArgs func;

      callDescription = lib.optionalString (context != null) " (while calling ${context})";
    in
    if isFunction func then
      if funcArgs == { } then
        func arguments
      else
        func (
          mapAttrs (
            n: _: arguments.${n} or (throw "callWith: argument `${n}` does not exist${callDescription}.")
          ) (lib.filterAttrs (name: hasDefault: builtins.hasAttr name arguments || !hasDefault) funcArgs)
        )
    else
      func;

  /**
    Calls a function with an attribute set of arguments, passing only the
    arguments the function expects. See `callWithContext` for details.

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
  callWith = callWithContext null;

  /**
    Calls `func` with `arguments` (via `callWithContext`) if it nests more
    function levels than `numLevels`, otherwise returns it unchanged. Used
    to detect the optional `extraArgs: ...` wrapper convention around
    modules and overlays.

    `callWithIfNestedFunc` is this function with a `null` context.

    The nesting depth is probed by speculatively applying the function to
    mock arguments whose values raise a catchable throw. Limitations, by
    construction of the probe:

    - `tryEval` only intercepts `throw`/`assert`; a body that fails in some
      other way before returning (e.g. importing a missing file) still
      aborts the surrounding evaluation.
    - A plain lambda (`functionArgs` is empty) receives the throw itself as
      its argument, so an ellipsis-only set pattern (`{ ... }: ...`)
      force-matches it and probes as depth 1. An `extraArgs` level must
      therefore either be a plain lambda or declare at least one named
      argument.

    # Type

    ```
    callWithIfNestedFuncContext :: (String | Null) -> Int -> (a -> b) -> AttrSet -> Any
    ```
  */
  callWithIfNestedFuncContext =
    context: numLevels: func: arguments:
    let
      arity =
        f:
        if isFunction f then
          let
            args = functionArgs f;

            probe = throw "nix-utils-lib arity probe";

            # An empty-set mock would turn any attribute access on it into
            # an uncatchable eval error; handing over the throw keeps a
            # strict body inside tryEval's reach.
            mockArg =
              if args == { } then
                probe
              else
                builtins.listToAttrs (
                  map (name: {
                    inherit name;
                    value = probe;
                  }) (builtins.attrNames args)
                );

            attempt = builtins.tryEval (f mockArg);
          in
          if attempt.success && isFunction attempt.value then 1 + arity attempt.value else 1
        else
          0;
    in
    if (arity func > numLevels) then callWithContext context func arguments else func;

  /**
    Calls `func` with `arguments` if it nests more function levels than
    `numLevels`, otherwise returns it unchanged. See
    `callWithIfNestedFuncContext` for details and limitations.

    # Type

    ```
    callWithIfNestedFunc :: Int -> (a -> b) -> AttrSet -> Any
    ```
  */
  callWithIfNestedFunc = callWithIfNestedFuncContext null;
}
