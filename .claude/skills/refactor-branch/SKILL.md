---
name: refactor-branch
description: Rewrite the current branch's history in place (same split-off point) so it matches the repo's git conventions - split, squash, reorder, and reword commits; offers branch splits for mixed topics. Pass "no-check" to skip the final checks.
---

# Refactor the current branch's history

Rewrites the branch onto its EXISTING split-off point - this is history
cleanup, not a rebase onto newer main. The target shape is defined by
CLAUDE.md's git rule (logical units, mechanical churn separated,
Conventional-Commit messages) - read it first; this skill only adds the
mechanics.

## Steps

1. **Preconditions**: refuse on `main`; require a clean worktree (ask the
   user to commit - e.g. via /commit - or stash first). Determine the
   base: `git merge-base main HEAD` (fall back to `origin/main`).

2. **Safety first**: create a backup ref at HEAD:
   `git branch backup/<branch>-$(date +%Y%m%d-%H%M%S)`. If the branch has
   an upstream and `git rev-list @{u}..HEAD` shows the commits being
   rewritten are already pushed, STOP and get explicit user confirmation
   before rewriting published history.

3. **Analyse**: `git log --reverse --stat <base>..HEAD` plus the aggregate
   `git diff <base> HEAD`; design the target commit series per the
   conventions.

4. **Branch split check**: if the series mixes several independent
   `<type>/<topic>` topics, propose a split before rewriting: which
   commits move to which new branch (independent topics branch from the
   base; dependent work stays stacked), with suggested names. Ask the
   user - they may decline and keep one branch. On an accepted split:
   create the new branches from the base, cherry-pick each branch's
   commit run, and reduce the current branch to what remains.

5. **Execute** - pick the fitting strategy:

   - Boundaries mostly right (reorder/squash/fixup/reword): scripted
     non-interactive rebase. Write a todo file and run
     `GIT_SEQUENCE_EDITOR='cp <todo-file>' git rebase -i <base>`;
     interactive editors are unavailable, so reword via a `pick` followed
     by an `exec git commit --amend -m '<message>'` line.
   - Boundaries hopeless (e.g. a stack of WIP commits): reset softly to
     the base (`git reset --soft <base>`), then rebuild the series from
     the staged aggregate using the /commit splitting procedure.

6. **Invariant - the tree never changes**: without a branch split,
   `git diff <backup-ref> HEAD` must be empty afterwards; with a split,
   the backup tree must equal the union of the resulting branch tips. On
   any mismatch or a failed rebase, `git reset --hard <backup-ref>` and
   report what happened.

7. **Verify and report**: run `nix flake check --no-build` and
   `nix fmt -- --fail-on-change` on the tip (skip when the user passed
   `no-check`), show the resulting `git log --oneline`, and name the
   backup ref for rollback. Never push - if the branch was already
   published, tell the user a force-push is theirs to do.
