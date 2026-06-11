---
description: Scaffold a reversible, idempotent data migration (FutureProof safe pattern)
argument-hint: "<what to change, e.g. rename X to Y / backfill column Z>"
allowed-tools: Bash, Read, Write, Edit
---

Create a data migration for: **$ARGUMENTS**

Follow FutureProof's safe-migration pattern (see
`db/migrate/20260526120000_rename_motoko_agent_to_akane.rb` as the reference):

- **Idempotent** — re-running is a no-op (guard every change with an existence check).
- **Reversible** — implement `down`; if a step is a one-way bug fix, leave it out
  of `down` and say so in a comment.
- **Collision-safe** — before renaming to a new unique value, check the target is free.
- **Insulated from model changes** — use bare `ActiveRecord::Base` subclasses
  (`self.table_name = ...`) inside the migration, NOT app models (no validation drift).
- **No destructive ops** — never drop/truncate/delete without an explicit instruction
  in the request above; the guardrail hook will block `db:drop`/`db:reset` anyway.

Steps:
1. Inspect the current data first (`bin/rails runner` read-only) so the migration
   handles exactly what exists.
2. Write the migration with a timestamp after the latest in `db/migrate/`.
3. Apply ONLY this migration: `bin/rails db:migrate:up VERSION=<ts>`.
4. Verify the result, then test reversibility: `db:migrate:down` then `db:migrate:up`.
5. Report what changed. Do NOT touch production — it migrates on the next deploy.

Use the default rvm ruby (don't prepend the homebrew ruby path).
