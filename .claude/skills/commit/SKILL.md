---
name: commit
description: Commit changes following the repo's git conventions (CLAUDE.md). Default is the staged set (or everything if nothing is staged); pass "all" to stage and commit everything.
---

# Commit following the repo conventions

The conventions themselves (branch names, subject format, scopes,
granularity, bodies) live in CLAUDE.md under "Rules" - read the git rule
first and follow it; this skill only adds the mechanics.

## Steps

1. **Pick the working set**:

   - Argument `all`: run `git add -A` and operate on everything.
   - No argument: if `git diff --cached --quiet` reports staged changes,
     operate ONLY on the staged set and leave unstaged work untouched;
     otherwise `git add -A` and operate on everything.

2. **Guard rails**: never commit on `main` - stop and offer to create a
   `<type>/<topic>` branch first. Never push.

3. **Split into logical units** (see CLAUDE.md for what a unit is). Work at
   file level only - no hunk surgery. Derive the scope from the paths:

   - `lib/<part>.nix` -> `<part>` (`imports`, `functions`, `files`),
     `lib/default.nix` -> `lib`;
   - `flake-modules/partition-<p>*.nix` -> `<p>` (`nixos`,
     `home-manager`, ...); `flake-modules/default.nix` and
     `flake-modules/internal/` -> `flake-module`;
   - `README.md` -> `readme`; `dev/` -> `dev`; repo-wide sweeps ->
     `treewide`.

   Commit each unit with `git commit -m ... -- <paths>`. That commits the
   worktree content of those paths, so it is only safe while worktree ==
   index for them: check `git status --porcelain` first, and if any file
   in the working set has BOTH staged and unstaged modifications, do not
   split around it - put all such files into a single commit (or fall
   back to one commit overall) and tell the user why.

4. **Messages**: per CLAUDE.md. Pull body content (rationale, accepted
   tradeoffs, consumer-breaking changes) from the task context that
   produced the change. End every commit message with:

   ```
   Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
   ```

5. **Wrap up**: show the created commits (`git log --oneline -<n>`) and
   remind the user that the branch tip must pass
   `nix flake check --no-build` and `nix fmt -- --fail-on-change` before
   review - do not run them automatically.
