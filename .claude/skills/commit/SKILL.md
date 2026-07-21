---
name: commit
description: Commit changes following the repo's git conventions. Default is the staged set (or everything if nothing is staged); pass "all" to stage and commit everything.
---

# Commit following the repo conventions

The conventions themselves (branch names, subject format, granularity,
bodies) live in the repo's CLAUDE.md git rules and any docs they link -
read them first and follow them; this skill only adds the mechanics.

## Steps

1. **Pick the working set**:

   - Argument `all`: run `git add -A` and operate on everything.
   - No argument: if `git diff --cached --quiet` reports staged changes,
     operate ONLY on the staged set and leave unstaged work untouched;
     otherwise `git add -A` and operate on everything.

2. **Guard rails**: never commit on the default branch (from
   `git symbolic-ref refs/remotes/origin/HEAD`, falling back to `main`) -
   stop and offer to create a `<type>/<topic>` branch first. Never push.

3. **Split into logical units** (one self-contained change each;
   mechanical churn like renames or formatting separated from behaviour
   changes). Work at file level only - no hunk surgery. Derive the scope
   from the paths: use the component or top-level area a file belongs to,
   following any scope rules in the repo's CLAUDE.md or docs; repo-wide
   sweeps -> `treewide`.

   Commit each unit with `git commit -m ... -- <paths>`. That commits the
   worktree content of those paths, so it is only safe while worktree ==
   index for them: check `git status --porcelain` first, and if any file
   in the working set has BOTH staged and unstaged modifications, do not
   split around it - put all such files into a single commit (or fall
   back to one commit overall) and tell the user why.

4. **Messages**: per the repo conventions. Pull body content (rationale,
   accepted tradeoffs, operator follow-ups) from the task context that
   produced the change. Mark agent commits with a Co-Authored-By trailer
   naming the agent, e.g.:

   ```
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

5. **Wrap up**: show the created commits (`git log --oneline -<n>`) and
   remind the user that the branch tip must pass the repo's checks (its
   verify skill or check script) before review - do not run them
   automatically.
