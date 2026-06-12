# Launch readiness — FutureProof Console
*Written 2026-06-13 (overnight run). Fact-grounded: every claim is backed by
a merged PR, a test, or a named gap.*

## Where we are
The Console (`/console`) is a complete, tested operations system: 28 sections,
~1,175 tests (0 failures), four CI-enforced quality gates (full suite,
CSP report, console:lint, route-crawling smoke tests), every page verified by
authenticated crawl before merge. The legacy `/admin` still runs in parallel,
untouched. `docs/CONSOLE_PARITY_MAP.md` accounts for every legacy action.

### The business can, today, from the Console
- **Originate**: pipeline → KYC/AML decisions → checklist → approve with terms
  → contract + pool allocation (graceful, audited failure path)
- **Service**: holiday/at-risk/complete transitions (audited, reasons),
  income-payment ledger per contract, customer messaging, support tickets
  with AI-draft review
- **Fund**: wholesale funders → priced pools → facility headroom → audited
  top-ups; suspended funders leave pickers but keep history
- **Distribute**: lender + broker onboarding checklists, agreements with full
  signature lifecycle, admin invitations, broker commissions ledger with
  audited pay runs
- **Govern**: legal register per jurisdiction (the public pages now actually
  serve it — see bug #1 below), prompt change-control via GitHub, audit log,
  security overview, AI-agent oversight

## Pre-existing bugs found and fixed during the rebuild
1. **Public legal pages never worked**: the controller actions sat below
   `private`, so Rails implicit-rendered hardcoded "Coming Soon" fallbacks in
   every environment. Fixed; pages serve jurisdictional LegalDocuments.
2. **KYC rejection always crashed** (wrote a non-existent column).
3. **Nested workflow steps could never save** (missing `inverse_of`).
4. **Published mortgage-contract fork-on-edit never fired** (checked
   `content_changed?` before assignment, dropped the mortgage association).
5. **Broker edit form had never saved** (unscoped form URL — fixed pre-rebuild).
6. **Commission-rate create failed validation** (no `active` default).

## What still stands between here and a real launch

### Must-do (blocking)
- [ ] **CTO end-to-end walkthrough** of the full origination→servicing flow on
  localhost with realistic data.
- [ ] **Production migrations**: three are queued and unrun in production —
  legal consolidation (additive), partner status (additive),
  plus any dependabot schema drift. Staging has run them via release_command.
- [ ] **Neon DB password rotation** (outstanding since 2026-06-11; the old
  password is in git history).
- [ ] **Phase 4 cutover decision**: parity map review → `/admin` redirects →
  delete admin namespace (code only) → separately-approved table drops
  (terms_of_uses, privacy_policies, terms_and_conditions,
  business_process_workflows). Console and admin currently double-maintain.
- [ ] **EPM annuity rates**: 15/20/25/30-year rates in EpmModelConfig are
  PROVISIONAL pending Pavel's validation (only the 10-year 2.0% is validated).
  Quotes are persisted with `term_validated` flags, but launch pricing needs
  the validated table.

### Should-do (launch week)
- [ ] **Payments execution**: the Distribution ledger displays payments;
  nothing in the app *executes* them (no payment-provider integration).
  Decide: manual ops + recording, or integrate before launch.
- [ ] **Commission accrual**: BrokerCommission rows are read/paid in the
  Console, but nothing *creates* them automatically on settlement —
  `Application#approve!` calculates but verify end-to-end creation.
- [ ] **2FA for admins** (Devise lockable/trackable are on; no second factor).
- [ ] **Error-notification drill**: trigger the Diagnostics test error in
  production once, confirm the email arrives.
- [ ] **Demo-data hygiene**: confirm prod has no `demo: true` rows; dashboards
  exclude them but lists don't filter by default.

### Defer (post-launch, by design)
- AgentTask approval queue (waiting for runtime agents to act autonomously)
- Prompt eval suite as a CI gate for prompt PRs (AI_BUILD_SPEC §8)
- Customer statements (PDF) generation
- Reconciliation views over the payments waterfall
- Visual workflow builder (form builder covers the model; see parity map)

## Operating model reminders (unchanged)
Merges to master auto-deploy **staging** only. Production moves solely via the
manual "Promote to Production" workflow (type PROMOTE) — and per the standing
instruction, only on explicit CTO sign-off.
