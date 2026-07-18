---
name: verify
description: Verify changes to this repo by evaluating the flake and forcing the eval test suite. Eval only, never build large closures.
---

# Verify nix-utilities changes

Verification here means evaluation: the library's behaviour is eval-time
behaviour, and its test suite is pure eval assertions. Never build large
closures; building small dev tooling is fine when it is the direct way to
verify a change.

## Steps

1. **Force the test suite** (all assertions run at eval):

   ```sh
   nix eval .#checks.x86_64-linux.nix-utils-lib.name
   ```

   When a change adds behaviour the suite does not cover (discovery,
   claiming, call conventions), extend `dev/checks/nix-utils-lib.nix` and
   its fixtures first. Fixtures are data - keep them out of the
   formatter's reach (`dev/checks/fixtures/` is treefmt-excluded).

2. **Check the whole flake evaluates**:

   ```sh
   nix flake check --no-build
   nix eval .#flakeModules --apply builtins.attrNames
   ```

3. **Lint and format**: `nix fmt -- --fail-on-change`.

4. **Consumer-shaped changes** (discovery, claiming, output names or
   types): these cannot be exercised here - nix-utilities has no
   home-manager or nixos tree of its own. State the consumer impact
   explicitly instead (a BREAKING paragraph in the commit body);
   consuming flakes verify them with their own eval tooling when they
   bump.
