# FutureProof EPM — Budget MVP Build Plan

**Prepared for:** Incoming CTO  •  **Classification:** Internal  •  **Date:** April 2026  •  **Version:** 1.1

> **Note.** This is the lean, budget-constrained alternative. A companion document — *FutureProof EPM — Stakeholder-Gated Build Plan* — sets out the larger stakeholder-milestoned alternative for formal stakeholder-meeting use. The two plans share architecture and reusable services; they differ in scope, ceremony, and cost.

## Purpose

This paper is the implementation plan for the FutureProof Equity Preservation Mortgage (EPM) Budget MVP. It assumes a small delivery team (one engineer plus one business-liaison / BA) and sets out the requirements, technology, deploy gates, resources, costs and timeframes needed to take the product from the current demonstrator to a live pilot able to originate a first cohort of mortgages.

It is intentionally prescriptive. A CTO joining the business should be able to read this paper and execute against it without re-deriving the scope.

## Executive Summary

Two people. Twenty-two weeks. AUD 185k. One Australian pilot, 5–10 mortgages, live and reconciling.

We harden the existing Rails demonstrator, integrate Blackrock for the investment leg and a non-bank lender for the funding leg, and ship behind six test-driven deploy gates. No partner is signed yet; partner sign-up is week-1 work, in parallel with the build.

The rest of this paper is the detail.

## 1. Requirements

### 1.1 The existing prompt — what we are validating

The "prompt" is the product concept already documented in the board papers: an EPM that lets a homeowner release equity, places the released cash into a diversified Blackrock-managed portfolio (≈70% equity ETFs / ≈30% fixed income), pays the homeowner a guaranteed income of roughly 1.5% of property value p.a., and is funded in the wholesale market by a non-bank lender counterparty. Returns above the guaranteed income flow to the funder and the equity investor according to the waterfall documented in the v14c actuarial review.

That prompt is internally consistent. It has not yet been externally validated. The requirements workstream is explicitly a validation exercise, not a discovery exercise.

### 1.2 Stakeholders and what they must sign off

| Stakeholder | What they sign off | Evidence required |
|---|---|---|
| Blackrock (investment counterparty) | Portfolio construction, rebalancing, API contract, custody, reporting | Signed IMA, API integration letter, test portfolio seeded |
| Non-bank lender (funder) | Funding agreement, wholesale rate, drawdown mechanics, security | Term sheet, API spec, reconciliation test |
| Regulator (ASIC for AU pilot) | Product disclosure, responsible lending, dispute handling | Product Disclosure Statement filed, Target Market Determination issued |
| External actuary | Pricing, capital, reinsurance structure | Countersigned actuarial report |
| External legal | Contract suite, jurisdictional compliance, PII handling | Legal opinion, contract templates |
| Customer (pilot cohort) | Product is understandable and valued | 10 signed customer intents, validated quote journey |
| Board | Risk appetite, pilot cap, go/no-go at each gate | Minuted approvals at Gate 0, Gate 2, Gate 4 |

### 1.3 Validation process — from prompt to signed requirements

The BA owns this workstream. Cadence is weekly. Each functional area below has an owner, a primary stakeholder, an artefact, and a gate it must pass before the engineer starts building against it.

The process is:

1. BA produces a one-page requirements brief per functional area, derived from the existing board papers.
2. Brief is put in front of the relevant stakeholder in a recorded session. Questions are captured.
3. Brief is revised, countersigned by the stakeholder, and entered into the requirements register.
4. Engineer converts the signed brief into acceptance tests before code is written (see Testing Strategy).
5. Any change to a signed brief requires a re-sign, not a comment.

**Functional areas (eight):**

| # | Area | Primary stakeholder | Signed artefact |
|---|---|---|---|
| F1 | Customer application & quote journey | Pilot customers + BA | Acceptance-tested user journey, 10 pilot intents |
| F2 | Underwriting & eligibility rules | Lender + actuary | Rule matrix, edge-case register |
| F3 | Pricing & actuarial model | Actuary | v14c model locked, test vectors signed |
| F4 | Contract generation & e-signing | Legal | Approved contract templates, jurisdiction pack |
| F5 | Investment flow (Blackrock leg) | Blackrock | Integration spec, sandbox reconciliation |
| F6 | Funding flow (lender leg) | Non-bank lender | Drawdown API spec, reconciliation spec |
| F7 | Income payments & servicing | Lender + customer | Payment schedule, dispute flow |
| F8 | Reporting & regulator pack | Regulator + board | PDS, TMD, monthly report template |

### 1.4 Testing strategy

Testing is split into code tests (fast, automated, block CI) and process tests (slower, human-in-the-loop, block deployment).

**Code tests**

- **Unit tests** — every service class, every calculation path. Target: ≥90% line coverage on `app/services` and `app/models`.
- **Integration tests** — every controller endpoint, every Stimulus interaction. Current suite is 382 tests; MVP target is ≥1,200.
- **Model fidelity tests** — golden-vector tests against the v14c Monte Carlo. Any drift in PoC, waterfall, surplus split, or run-off mechanism fails the build.
- **Contract tests** — recorded-request tests against Blackrock and lender APIs. Pact-style consumer-driven contracts so either side breaking the contract fails CI.
- **Security tests** — Brakeman, bundler-audit, dependency scan, CSP compliance check. All must pass clean.

**Process tests**

- **Stakeholder walkthrough** — each functional area walked through live with the signing stakeholder before the gate is cleared. Recorded.
- **Dual-control origination rehearsal** — end-to-end mock origination with founder + BA acting as ops, run four times before Gate 4. Each rehearsal produces a defects list that must be empty before pilot.
- **Tabletop incident** — one simulated incident (portfolio drawdown, funder outage, customer dispute, PII breach) per gate from Gate 2 onwards. Pass criterion: incident runbook worked without improvisation.
- **Regulatory review** — PDS and TMD reviewed by external counsel before Gate 3. Sign-off is a binary gate.

## 2. Technology

### 2.1 Target architecture

The architecture already exists in the demonstrator and is retained. No rewrite.

- **Application:** Rails 8.1, Ruby 3.4, PostgreSQL 16, Stimulus, custom CSS design system (no framework).
- **Services:** Pricing engine (`CalculationEngine`), quote service, Python Monte Carlo service (callable for v14c model fidelity), jurisdiction service, agent router.
- **Integrations:** Blackrock (investment), non-bank lender (funding), e-sign (DocuSign or equivalent), payments (Stripe for fee collection; direct entry for wholesale flows), email (SES), identity verification (jurisdictional provider).
- **Data:** PostgreSQL as system of record. Daily backup to S3 with point-in-time recovery. PII encrypted at rest.

The explicit architectural decision is to resist new abstractions. The demonstrator is working. MVP work is hardening, not reinvention.

### 2.2 Hosting

**Primary:** Fly.io (already in use). Single region to start (Sydney for AU pilot). Dedicated Postgres with read replica.

**Why Fly.io for MVP:** zero-config Rails deployment, fast rollback, cheap at our scale, and we are already on it. Moving to AWS or GCP is a Series A decision, not an MVP decision.

**Secondary:** AWS S3 for backups and document storage (contracts, signed PDFs, regulatory artefacts). CloudFront for public static assets only. No Lambda, no SQS, no DynamoDB. Keep the estate small.

**Environments:**

| Env | Purpose | Data | Who can deploy |
|---|---|---|---|
| dev | Engineer laptop | Synthetic | Engineer |
| staging | Integration + stakeholder demos | Masked production-shape | CI on merge to main |
| sandbox | Blackrock/lender integration testing | Synthetic + partner sandbox | CI on tag |
| production | Live pilot | Real PII, real money | CI on signed release tag only |

### 2.3 Build pipeline

GitHub Actions. One pipeline, five stages, fail-fast.

1. **Lint** — RuboCop, ESLint, CSP scan. <2 min.
2. **Unit + integration tests** — full Rails suite. <8 min.
3. **Model fidelity tests** — golden-vector Monte Carlo comparison. <5 min.
4. **Security scan** — Brakeman, bundler-audit, trivy. <3 min.
5. **Build & sign artefact** — Docker image tagged with commit SHA, signed with cosign, pushed to registry.

Pipeline budget: <20 minutes from push to signed artefact. If it drifts above, it is a bug.

### 2.4 Deploy gates — test-driven deployment

Every deploy to production must pass six gates, in order. A gate is binary: green or red. Red blocks promotion. No overrides.

| Gate | Name | Criterion | Automated? |
|---|---|---|---|
| G1 | Artefact integrity | Signed Docker image, SBOM present, no CVE above medium | Yes |
| G2 | Test parity | Full suite green on the exact commit being deployed | Yes |
| G3 | Model fidelity | v14c golden vectors match within tolerance | Yes |
| G4 | Partner contracts | Blackrock + lender contract tests green against sandbox | Yes |
| G5 | Smoke on staging | Post-deploy smoke suite green on staging with production-shape data | Yes |
| G6 | Human sign-off | Engineer AND BA both tick the release checklist in the release PR | Manual |

Gates 1–5 run as GitHub Actions jobs. Gate 6 is a branch-protection rule requiring two reviewers on the release PR. Production deploys are triggered by tagging a release; the pipeline refuses to proceed past any red gate.

Rollback is one command: `fly releases rollback`. Post-incident, a rollback must be accompanied by a written root-cause within 24 hours before the next deploy is permitted.

### 2.5 External integrations — Blackrock and the non-bank lender

**Blackrock.** We assume no commercial relationship at plan start. The BA's week-1 task is to open the conversation with Blackrock and negotiate access to the appropriate documented surface. The technical integration plan assumes the publicly documented Aladdin-adjacent APIs (portfolio construction, order placement, position and NAV reporting) supplemented by iShares data feeds for ETF pricing. Integration is built against Blackrock's sandbox before any live portfolio is seeded. All contract tests run on every deploy.

**Non-bank lender.** Counterparty choice is a business decision, not a technical one. The technical requirement on the lender is: REST API for drawdown, reconciliation file (daily, SFTP), and a named technical contact for incident escalation. The lender is chosen partly on their ability to move quickly on integration; a slow integration is a dealbreaker regardless of pricing.

Until both counterparties are contracted, the integration layer runs against an in-repo fake that simulates both sides. The fake is the first thing built (week 2) because it unblocks everything else. Switching from fake to real sandbox to real production is a configuration change, not a code change.

## 3. Resources

### 3.1 Core team

| Role | FTE | Responsibility |
|---|---|---|
| Founder / Engineer | 1.0 | All engineering, architecture, deploy, on-call |
| Business Analyst / Liaison | 0.6 | Stakeholder management, requirements briefs, sign-off chasing, pilot ops |

That is the team. Everything else is bought in.

### 3.2 External specialists (contracted, not hired)

| Specialist | Engagement | When |
|---|---|---|
| External actuary | Retainer, fixed-fee review per model change | Weeks 1, 8, 16 |
| External legal (lead jurisdiction) | Fixed fee for contract suite + PDS, then hourly | Weeks 1–6, then as-needed |
| External counsel (other jurisdictions) | Deferred to post-MVP | N/A for MVP |
| Security review | Fixed-fee penetration test | Week 20 |
| Auditor (financial ops) | Pilot-period retainer | Weeks 18–22 |

### 3.3 Board and advisory

Board meetings at Gate 0 (kickoff), Gate 2 (partners signed, build underway), and Gate 4 (pilot go/no-go). No weekly board involvement. Advisory input on Blackrock and lender introductions is the highest-leverage use of board time in weeks 1–4.

## 4. Costs and timeframes

### 4.1 Phase plan (22 weeks)

| Phase | Weeks | Gate | Outcome |
|---|---|---|---|
| Phase 0 — Partner approach | 1–4 | G0: Partner conversations live | Blackrock + lender in active negotiation; requirements briefs drafted |
| Phase 1 — Harden & fake | 2–8 | G1: Platform hardened | Rails app production-grade; fake Blackrock + lender; full test suite ≥1,200 tests |
| Phase 2 — Real sandboxes | 8–14 | G2: Sandbox integrations green | Live Blackrock sandbox + lender sandbox reconciling daily |
| Phase 3 — Compliance & contracts | 12–18 | G3: Regulatory pack signed | PDS, TMD, contract suite, legal opinion complete |
| Phase 4 — Origination rehearsal | 16–20 | G4: Pilot go/no-go | Four end-to-end rehearsals clean; board approves pilot |
| Phase 5 — Pilot | 20–22 | G5: First cohort originated | 5–10 mortgages live, monthly reporting flowing |

Phases overlap by design. A solo engineer cannot afford sequential waterfall; the BA's job is to keep the partner and compliance workstreams ahead of the engineering workstream so the engineer is never blocked.

### 4.2 Cost estimate (AUD)

| Item | Cost | Notes |
|---|---|---|
| Founder / Engineer salary (22 wks, below-market) | 85,000 | Assumes 120k annualised |
| BA / Liaison (0.6 FTE, 22 wks) | 42,000 | Assumes 160k annualised, fractional |
| External actuary (3 reviews) | 18,000 | Fixed-fee engagement |
| External legal (contract suite + PDS) | 25,000 | Fixed fee for lead jurisdiction |
| Penetration test | 8,000 | One-off at Gate 5 |
| Auditor retainer (pilot period) | 5,000 | Pilot cohort only |
| Infrastructure (Fly.io, AWS, SaaS) | 2,000 | 22 weeks of cloud + tooling |
| **Total cash** | **185,000** | |
| Contingency (15%) | 28,000 | Recommend held as reserve |
| **Total with contingency** | **213,000** | |

Assumptions:

- No partner retainers; Blackrock and the lender are commercial, not cash costs.
- Founder salary is the single largest line item; it is also the primary flex if cash is tight.
- Contingency is for legal re-work (most likely source of overrun) and for a second jurisdiction's legal review if the pilot is moved mid-build.
- Capital to fund the mortgages themselves is not included in this budget; that is the wholesale funder's balance sheet.

### 4.3 Timeframe summary

- **First real Blackrock sandbox trade:** week 10
- **First end-to-end origination in rehearsal:** week 16
- **Regulatory pack signed:** week 18
- **Pilot origination begins:** week 20
- **First cohort fully live with monthly reporting:** week 22

## 5. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Blackrock access slower than planned | High | High | Fake-first integration means build continues; swap at sandbox time; escalate through board |
| No lender signed by week 8 | Medium | High | Approach 3 lenders in parallel from week 1; BA owns pipeline |
| Regulatory surprise (PDS / TMD) | Medium | High | External counsel engaged week 1; regulator approached informally before formal filing |
| Solo-engineer bus factor | Constant | Existential | Architecture is deliberately boring; runbook is written as we build; code review by contracted senior Rails engineer each gate |
| Model drift during hardening | Low | High | Golden-vector tests in CI; actuary countersigns every model change |
| Scope creep from stakeholders | High | Medium | Signed requirements are immutable; changes require re-sign and re-price |

## 6. Go / no-go criteria for pilot

At Gate 4, the board decides pilot go/no-go. Criteria are binary:

- All six deploy gates green for 14 consecutive days on staging.
- Four clean end-to-end origination rehearsals.
- Blackrock and lender production contracts signed.
- PDS and TMD filed.
- Incident runbook tested in one live tabletop.
- Founder and BA both recommend go in writing.

Any red is no-go. No exceptions. A no-go is not a failure; it is the system working.

## Appendix A — What is explicitly out of scope for MVP

- Multi-jurisdiction launch. MVP is one jurisdiction (AU).
- Broker channel. Direct-to-customer only.
- Mobile app. Responsive web only.
- Secondary market / securitisation. On the backlog.
- In-house actuarial team. External only.
- Self-serve customer portal beyond application + quote + e-sign + statement view.

## Appendix B — What the CTO inherits on day one

- Working Rails 8 codebase, 382 passing tests, deployed to Fly.io.
- Full board paper set: investor report, risk analysis, actuarial review, wholesale funder memo, reinsurance structure, tax analysis for four jurisdictions.
- v14c Monte Carlo model with locked golden vectors.
- Multi-jurisdiction configuration already built (only AU activated for pilot).
- Custom CSS design system, Stimulus front-end, CSP-strict policy.
- This plan.

End of document.
