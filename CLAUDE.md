# nix-utilities

An opinionated flake module for structuring Nix projects with flake-parts
partitions. See [README.md](README.md) for the layout, behaviour, and
caveats - it is the single home for how the library works.

## Structure

- `lib/`: nix-utils-lib (`files`, `functions`, `imports`), built with
  `makeExtensible`; `flake.nix` exposes it as `nix-utilities.lib`.
- `flake-modules/`: the exposed flake modules - `default.nix` (partition
  claiming), one `partition-*.nix` per partition and sub-partition, shared
  machinery in `internal/lib.nix` (internal, not part of the API).
- `dev/`: development tooling, wired as this repo's own dev partition
  (`dev/flake.nix` pins the dev-only inputs; `dev/flake-module.nix` adds
  treefmt and pre-commit). The repo dogfoods itself: `flakeModules.*` comes
  from its own flakeModules partition walking `flake-modules/`.
- Eval tests: `dev/checks/nix-utils-lib.nix` with fixtures under
  `dev/checks/fixtures/` (fixtures are treefmt-excluded on purpose - they
  are data, and reformatting them changes what the tests test).

## Rules

- Don't build large closures; evaluation is the verification currency here.
  `nix flake check --no-build`, `nix eval`, lock/prefetch operations, and
  building small dev tooling are all fine.
- Verify with `nix flake check --no-build`, then force the test suite:
  `nix eval .#checks.x86_64-linux.nix-utils-lib.name`. Format with
  `nix fmt` (treefmt: nixfmt strict, statix, mdformat).
- Write comments and docs for humans, with plain ASCII typography: no UTF-8
  special symbols (em dashes, fancy quotes, unicode arrows or ellipses);
  ASCII punctuation like -> and => is fine. Comments say why, not what:
  state invariants and intent, and link the README instead of restating it.
  Use British English in Markdown docs and prose comments (not code
  identifiers).
- Keep the README in sync: when a change alters behaviour a section
  describes, update that section in the same change. Beware that this
  library's semantics are Nix-implementation-sensitive (symlinks,
  `pathExists`) - document which implementation a behaviour claim holds on.
- Git: work on `<type>/<topic>` branches; never commit to main and never
  push unless asked. Commit subjects are
  `<type>(<scope>): <imperative, lowercase>` (Conventional Commits with the
  component as scope); one logical change per commit; the body only carries
  a why the subject cannot. Scopes: `lib`, `imports`, `functions`, `files`
  for `lib/`; the partition name (`nixos`, `home-manager`, `overlays`,
  `packages`, `apps`, `dev`, `flake-modules`) or `flake-module` (the
  claiming module) for `flake-modules/`; `readme` or `docs` for docs;
  `dev` for tooling; `treewide` for sweeps. Mark agent commits with a
  Co-Authored-By trailer. Use the /commit and /refactor-branch skills for
  committing and history cleanup.
- Generated files (do not hand-edit): `.pre-commit-config.yaml` (nix-store
  symlink refreshed by the pre-commit tooling).
- Consumer impact: this library is consumed by other flakes. Behaviour
  changes to discovery, claiming, or output names are breaking for them -
  call them out explicitly (a BREAKING paragraph in the commit body) so
  downstream migrations can be planned.
