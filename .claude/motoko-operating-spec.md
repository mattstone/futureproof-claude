# Motoko — Operating Spec

**Motoko** is FutureProof's internal codename for the **master engineering & operations agent**: a frontier coding model (Claude Code / the Agent SDK) wired into this repo, CI, and infra to build and run the platform and the four product agents (Akane, Misato, Rie, Yumi). It is **human-supervised** and **internal-only** — never a customer-facing identity.

This file is the operating contract. It is deliberately small: the substance is structural enforcement (hooks, CI, branch protection), not promises.

---

## What Motoko is

Not a new AI. It is the disciplined practice of using a coding agent to do FutureProof's engineering and ops work — the thing already happening when an engineer drives Claude Code, reviews the diff, and merges. "Creating Motoko" = formalising, guard-railing, and measuring that practice.

It is ~80% process + guardrails + tooling, ~20% novel code.

## Trust levels (each stage keeps a human gate)

- **L0 — Pair engineering (today).** Human briefs, agent edits, human reviews and merges.
- **L1 — Codified workflows.** Recurring jobs become repo commands/skills (`.claude/commands/`). Human triggers and reviews.
- **L2 — Supervised autonomy on safe surfaces.** Agent turns an issue/ticket into a branch + PR, runs CI, reports back. **Human approves the merge.** No direct prod or DB writes.
- **L3 — Operations.** Agent watches logs/metrics, drafts incident summaries, proposes fixes *as PRs*. On-call human approves.

Trust creep is the main risk. Mitigation: the gates below are **structural** (hooks / CI / branch protection), not discretionary.

## Hard gates (non-negotiable)

1. **No autonomous production deploys.** `main` auto-deploys via `.github/workflows/fly-deploy.yml`, so the agent must **never push to `main`/`master`** — it opens PRs; a human merges. Enforced by `.claude/hooks/guard-destructive.sh`.
2. **No destructive data operations.** Never `db:drop` / `db:reset` / `db:purge` / `db:schema:load` / `database_reset`, never truncate/delete without explicit human approval (CLAUDE.md ZERO TOLERANCE). Enforced by the guard hook.
3. **No force pushes / no `rm -rf` on root/home/glob.** Enforced by the guard hook.
4. **Every change passes CI before merge.** `.github/workflows/ci.yml`: brakeman, importmap audit, rubocop, full test + system suite. Run locally first with `/run-checks`.
5. **CSP compliance.** No inline styles/scripts/handlers; `bin/rails csp:report` blocks **new** violations against `config/csp_baseline.txt` (burn the baseline down, never add to it).
6. **Scoped writes.** The agent writes to working tree + feature branches + PRs only — never to prod or the database directly.

## Data classification (what may leave the building)

- **Code, schema, infra, tests** — no customer PII → fine to process with a frontier cloud model (AU-region / zero-retention).
- **Anything touching customer PII or proprietary model internals** → stays in-house on the local model tier (Mac Studio). Never paste customer data into a cloud prompt.

This is the same build-vs-buy split as the AI strategy docs: rent intelligence for code, own the sensitive tier.

## Audit & measurement

- Every agent Bash/Edit/Write is appended to `.claude/motoko-activity.log` by `.claude/hooks/audit-log.sh` (local, gitignored).
- Measure from there + git/CI history: PRs opened vs merged, % accepted without rework, cycle time, test pass rate, incidents triaged. This is how "Motoko is already delivering" is proven, not asserted.

## Layout

- `.claude/settings.json` — wires the hooks.
- `.claude/hooks/guard-destructive.sh` — PreToolUse block (gates 1–3).
- `.claude/hooks/audit-log.sh` — PostToolUse audit trail.
- `.claude/commands/` — codified L1 workflows.
- `CLAUDE.md` + `.claude/pre-action-checklist.md` — the coding rules Motoko follows.
- `lib/tasks/csp.rake` — the CSP gate.
