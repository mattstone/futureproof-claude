# How code changes — the operating model

**One door. Graded locks. Earned keys.**

This is the canonical statement of how the FutureProof codebase is managed by
humans and AI agents together. The strategy documents (`PLATFORM_BUILD_BRIEF.md`
§10–12, `AI_BUILD_SPEC.md` §10) and the agent rules (`CLAUDE.md`,
`.github/workflows/claude.yml`) reference this file; per the one-rule
convention, the model is stated here and nowhere else.

Legend: ✅ live today · 🔜 planned next

## The principle

We do not trust *actors*; we gate the *pipeline*. Every change to the product —
whoever or whatever authored it — enters through the same door and faces locks
graded by what it touches, not by who made it. Autonomy is earned with a track
record, the same way an employee earns it.

## The actors (four today)

| Actor | Enters via | Identity on the change |
|---|---|---|
| CTO | branch + PR | git author |
| Business users | Admin → Prompts / Change Requests (never see git) ✅ | PR/issue opened in their name by the bridge, impact Q&A recorded verbatim |
| Claude Code (local agent) | branch + PR, guardrail-blocked from pushing to trunk ✅ | co-author trailer |
| Claude (GitHub Action) | `change-request` issues / `@claude` mentions → **draft** PR ✅ | action-authored PR linking the originating request |

## The door ✅

1. Every change is a **pull request** against `master` carrying an **impact
   assessment** ("does this affect data, functionality, or only
   wording/guidance?" — answered by the proposer, recorded permanently).
2. **CI** runs the full suite; the `test` job is a required check. (Lint and
   security scans run visibly but carry repo-wide debt and do not yet gate —
   making them gate is a standing maintenance goal.)
3. **The CTO reviews and merges** (CODEOWNERS). No agent merges. No actor —
   including the CTO's own tooling — pushes to `master` directly; branch
   protection and the local guardrail both enforce this. Admin bypass exists
   as the explicit emergency escape hatch.
4. **Merge deploys** (Fly, with migrations as the release step). 🔜 With
   staging in place, merge deploys to *staging* and production becomes a
   manual one-click promotion by the CTO.

## The locks — risk tiers

The impact assessment plus the paths a PR touches set its tier. Higher tier =
more evidence required before merge, and more of the CTO's attention.

| Tier | What it covers | Required evidence |
|---|---|---|
| **T0** | Prompt wording, copy, docs (`docs/prompts/**`, view text) | CI green; 🔜 prompt eval suite green (golden transcripts + advice-wall red-team) |
| **T1** | General application code | CI green + CTO review |
| **T2** | The financial core (`epm_model_config`, `quote_service`, `calculation_engine`), auth, migrations, legal templates | CI green incl. golden-number tests + CTO review with explicit checklist |
| **T3** | Workflows, deploy config, credentials, this document | CTO only, always |

## The keys — earned autonomy (the staircase, applied to code)

The capability staircase in `AI_BUILD_SPEC.md` §6 governs agents acting on the
*business*; the same steps govern agents acting on the *codebase*:

- **Step 1 — propose** ✅ *(all agents are here today)*: every agent change is
  a draft PR; a human decides.
- **Step 2 — act within a tier** 🔜: T0 changes whose gates are all green
  (CI + prompt evals) may merge without review — to staging only, never
  production. Promotion requires a sustained, measured **agreement rate**
  (share of agent PRs the CTO merged unedited — readable from GitHub history),
  not a demo.
- **Step 3 — standing duties** 🔜: scheduled maintenance agents (dependency
  bumps, lint/security-debt burn-down, flaky-test repair) operating at step 2
  rules. First target: clear the RuboCop/Brakeman debt so those CI jobs can
  become required checks, raising the floor for every author.

Demotion is instant and unceremonious: a bad merge drops the tier back to
step 1. The kill switch is removing the action's key.

## Environments & release

- ✅ Today: merge → production deploy (Fly, single app, migrations run as the
  release command so schema and code ship together).
- 🔜 Next: a **staging app**. `master` auto-deploys to staging; production is
  a deliberate promotion (one click or `fly deploy` after the CTO has used the
  staging site). This implements "test, then deploy" structurally instead of
  by discipline, and is the precondition for any step-2 autonomy.

## Incident path

Roll back by reverting the merge (a PR like any other) or redeploying the
prior Fly image for speed. The CTO's admin bypass on branch protection is the
sanctioned emergency route — use it, then backfill the PR. Secrets never live
in code: encrypted credentials, Fly secrets, and GitHub Actions secrets only.

## Why it's built this way

A single reviewer cannot scale by working harder; the system scales by making
most changes prove themselves mechanically (tests, evals, tiers) so human
judgement concentrates where it matters. The honest limits: the CTO remains
the merge authority and bus-factor by design at this stage; eval suites raise
the floor but do not replace review; agreement data takes weeks to mean
anything. The structure above is how those limits relax safely over time.
