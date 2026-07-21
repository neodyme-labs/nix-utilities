# Shared agent standards

Baseline rules for all Neodyme infrastructure repositories. Vendored from
the agent workspace (https://git.neodyme.one/Infrastructure/agent-workspace,
where `standards/` is the source of truth; the vendored version is recorded
in `.claude/standards-version`). Repo-specific rules in the repository's
own `CLAUDE.md` extend and override this file. Skills vendored alongside it
are standards-owned: their names are reserved and syncs overwrite and may
prune them, so repo-specific skills use other names. Keep this file to
about one page: every repo's agents load it as context.

## Writing

- Write for humans and agents at once: explicit, concrete, no tribal
  shorthand; there are no separate agent docs.
- Concise and practical, task-first: recipes and facts before theory. If
  a sentence changes nothing for the reader, delete it.
- One home per fact: link instead of duplicating. Cite real paths so
  claims are checkable.
- No hand-maintained catalogues that duplicate `ls` output: describe the
  pattern, let the tree be the inventory.
- Caveats are the point: write down the sharp edges, especially the
  awkward ones.
- Keep docs in sync: a change that alters behaviour, layout, or tooling a
  doc describes updates that doc in the same change.
- Plain ASCII typography: no UTF-8 special symbols (em dashes, fancy
  quotes, unicode arrows or ellipses); ASCII punctuation like -> and =>
  is fine. British English in prose, not in code identifiers.

## Comments

- Say why, not what: state the constraint or invariant the code cannot;
  never narrate the next line.
- Change history belongs in the commit message, never in comments.
- A deliberate deviation that looks like a mistake gets a comment saying
  it is intentional and why.
- A file whose role is not obvious from its path gets a one-sentence
  header; point to the owning doc instead of restating it.
- A comment that restates the adjacent code or an existing doc gets
  deleted.

## Git

- Work on `<type>/<topic>` branches; never commit to the default branch
  and never push unless asked.
- Commit subjects are `<type>(<scope>): <imperative, lowercase>`
  (Conventional Commits with the component as scope); one logical change
  per commit. Breaking changes carry `!` after the type/scope and a
  `BREAKING CHANGE:` footer describing the migration.
- The body carries only a why the subject cannot (rationale, accepted
  tradeoffs, operator follow-ups) and wraps at 72 columns; omit it when
  the subject says it all. Never narrate the diff: no file-list
  changelogs, no "this commit ..." prose. Issue references (`Closes #N`,
  `Refs #N`) go in footers, never in the subject or body prose.
- Mark agent commits with a Co-Authored-By trailer; never add session
  links or session trailers (e.g. `Claude-Session: ...`).
- Use the /commit and /refactor-branch skills for committing and history
  cleanup.

## Secrets

- Never perform secret operations: no `sops` invocations (decrypt, edit,
  rotate, updatekeys) and no reading, printing, or inlining secret
  material. Secret changes are operator actions; describe what needs doing
  instead.

## Verification

- Each repository defines how its changes are verified (a `verify` skill
  or a check script). Verification is repo-specific and deliberately not
  part of these shared standards; if the repository has neither, ask the
  user what verification means here and propose adding a `verify` skill.
