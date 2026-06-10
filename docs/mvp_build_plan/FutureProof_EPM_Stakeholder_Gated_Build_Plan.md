# FutureProof EPM — Stakeholder-Gated Build Plan

**Prepared for:** Stakeholder meeting  •  **Classification:** For Stakeholder Distribution  •  **Date:** April 2026  •  **Version:** 1.0

## Executive Summary

An Australian-first Equity Preservation Mortgage, built to pilot-live in **thirty weeks** by a two-person AI-first team and gated, one stakeholder at a time, by the people whose money and reputation sit on the platform: the wholesale funder, the lender, the investment partner, the reinsurer, the broker, the consumer. Every stakeholder signs their own scope, watches their own tests go green, and countersigns their own gate before we move on. Nothing ships on trust.

The capital ask is **AUD 700k**: a **AUD 285k** build through to pilot, a funded Year-1 Post-Live runway, a named reserve for the Fly.io → AWS migration when a counterparty first demands it, and an operational contingency buffer. External legal spend (contracts, PDS, broker accreditation, funder agreements, AFSL / ACL work) is funded from a separate legal budget and is not included in this ask. The output is a launched product, countersigned integration reports from every counterparty, a clean pen test, a filed PDS, and a live pilot cohort — not a prototype.

## 1. Team & Working Model

Two people.

- **CTO** — architecture, CI/CD, deploy gates, on-call, partner API integrations. Owns the release branch.
- **BA / Programmer** — stakeholder management, requirements briefs, acceptance-test authoring, and production-grade code generation via Claude prompts (AI-augmented). The BA is not a note-taker; they ship.

Working model is explicitly AI-augmented. The BA's workflow is:

1. Meet stakeholder, capture the scope verbally.
2. Write the one-page scope brief. Get stakeholder sign-off.
3. Convert the brief into executable acceptance tests.
4. Drive Claude prompts to generate the implementation against those tests.
5. CTO reviews, lands, and promotes through the gate.

Velocity assumption: AI-first 2-person team ≈ 1.8× pre-AI 2-person team. Documented honestly. Not 5×. Not 10×. The BA's bottleneck is stakeholder-facing work; AI helps, it does not replace.

### 1.1 AI-first — with explicit guardrails

We take an AI-first approach to delivery. Claude drafts most code, tests, and stakeholder briefs. We also accept openly that AI is not perfect — it hallucinates APIs, drifts on long context, and produces plausible-looking but subtly wrong code in regulated-finance domains. Our delivery process is built to contain those weaknesses rather than pretend they are absent.

Every change follows the same PR → deployment pipeline (see chart in the PDF companion). Humans set the intent (signed stakeholder brief, authored acceptance tests). AI drafts the implementation. Humans review line-by-line. Automation then enforces the rules: CI runs unit, contract, and model-fidelity tests against the locked v14c Optimised actuarial output; staging gates G1–G3 and production gates G4–G6 run on every release. On any red, the rework lands on the draft — never on the gate. AI buys us throughput per person, not ceremony skipped.

## 2. Stakeholder Milestones

Seven milestones. Sequenced funding-first: supply side before demand side.

For each milestone:
- **Stakeholder(s)** — primary plus any secondary
- **Signs off** — the one thing they countersign before the gate is closed
- **Scope artefacts** — one-page brief + acceptance-test list
- **Tests built first** — types: unit / integration / contract / model-fidelity / stakeholder-walkthrough / tabletop
- **Build deliverable** — concrete platform surface + services + admin screen
- **Gate criterion** — binary; green = all acceptance tests pass AND stakeholder signs
- **Weeks / dependencies / cost slice**
- **Key risk**

### M0 — Foundation (weeks 1–4, ~AUD 22k)

**Stakeholder:** FutureProof internal. **Signs off:** CTO.

**Scope:** harden the platform for production operation. Deliver the stakeholder-gate framework as a first-class piece of code so M1–M6 inherit it. Cloudflare in front of Fly.io Sydney; WAF rules on; rate limiting on; secrets out of the repo and into Fly secrets; database with point-in-time recovery; observability (Sentry + health checks + structured logs).

**Tests first:** unit/integration on the existing 382-test suite (target ≥600 by end of M0); security tests (Brakeman, bundler-audit, CSP scan); a smoke suite that runs post-deploy against staging.

**Build:** CI/CD pipeline with five stages (lint / test / model-fidelity / security / artefact); deploy gate framework (G1–G6 as inheritable Actions jobs); Admin skeleton (authenticated, audit-logged, role-based); Fly.io production hardened.

**Gate:** all five pipeline stages green on main for 14 consecutive days. Staging deploys automatic on merge. Production deploys behind a signed release tag.

**Risk:** under-investing here leaves every subsequent milestone slower. Mitigation: M0 is not compressed; it takes as long as it takes inside the 4-week window, and if it slips, everything slips with it.

### M1 — Wholesale Funder (weeks 5–10, ~AUD 42k)

**Stakeholder:** Non-bank wholesale funder. **Signs off:** funding agreement, wholesale rate, drawdown mechanics, reconciliation spec, security controls.

**Scope:** define the funding leg end-to-end. What triggers a drawdown, what data is exchanged, how reconciliations run, how disputes escalate, how incident communication works. The one-page scope brief is written week 5 by the BA and signed by the funder before any code is written.

**Tests first:** contract tests (Pact-style) against the funder's API spec; reconciliation fidelity tests (daily files match general ledger); drawdown mechanics (pre-approved limits, concentration rules, haircut logic); tabletop for a funder-side outage.

**Build:** in-repo fake funder (built first — unblocks M2 and M3); real sandbox integration against the funder's development environment; production connector with TLS-pinned mTLS. Admin surface: funder dashboard (positions, drawdowns, reconciliation state, dispute log).

**Gate:** reconciliation matches for 14 consecutive days across fake → sandbox → production, and the funder countersigns the integration test report.

**Risk:** no funder signed by week 5. Mitigation: approach 3 funders in parallel from week 1 (the BA's job). Fake-first architecture means build continues in parallel with the commercial negotiation.

### M2 — Lender (weeks 8–14, ~AUD 44k)

**Stakeholder:** Retail lender (AFSL holder). **Signs off:** origination rules, credit decision engine, servicing workflow, lender operational dashboard.

**Scope:** the rule matrix — who gets approved, under what LVR, with what income, under what property type. The servicing workflow — how statements are produced, how missed payments are handled, how redraws work (if any), how the payment waterfall is triggered. All codified, all acceptance-tested.

**Tests first:** rule-matrix tests (one test per approval pathway, one per rejection reason); servicing-workflow tests; AFSL responsible-lending compliance tests; stakeholder-walkthrough with the lender operations team (recorded).

**Build:** credit decision engine as a deterministic service; servicing workflow as controllers + background jobs; lender dashboard (applications in flight, approvals, rejections, servicing events).

**Gate:** lender-ops signs the rule matrix and the servicing runbook. Tests pass clean. Dependencies: M1 gate-green.

**Risk:** rule matrix churns as the lender discovers edge cases late. Mitigation: tests are authored by the BA during scope; changes require re-sign. Budget three rounds of iteration into the 6 weeks.

### M3 — Investment Partner (weeks 11–18, ~AUD 56k)

**Stakeholder:** BlackRock (working assumption — no commercial agreement exists at plan start). **Signs off:** portfolio construction spec, rebalancing policy, custody reporting, API contract, sandbox reconciliation.

**Scope:** the investment leg. What portfolio is constructed (the ≈70% equity ETF / ≈30% fixed income mix per the actuarial review); who holds custody; how rebalancing is triggered (band-based, time-based, or event-based); how NAV and position reporting is delivered; what data is returned daily and in what format.

**Tests first:** contract tests against the Aladdin-adjacent sandbox (portfolio construction, order placement, position and NAV retrieval); iShares pricing feed tests; model-fidelity tests (against v14c golden vectors); stakeholder-walkthrough with BlackRock technical; tabletop for BlackRock-side outage.

**Build:** investment connector behind an abstraction (the "Investment Partner Interface"). Concrete implementation against BlackRock; a second implementation against the fake. Admin surface: portfolio positions, NAV trajectory, rebalance events, reconciliation to Blackrock daily.

**Gate:** sandbox reconciliations clean for 14 consecutive days. BlackRock countersigns the integration test report. Dependencies: M1, M2 gate-green.

**Risk (primary unknown):** BlackRock does not sign in the plan window. Plan B: the Investment Partner Interface abstraction allows substitution of a domestic managed-account provider (Macquarie, Mason Stevens, Netwealth) on ~4 weeks of additional work. The abstraction is built regardless of partner choice.

### M4 — Insurance / Reinsurance (weeks 14–20, ~AUD 38k)

**Stakeholders:** LMI provider + tail-risk reinsurer. **Signs off:** policy binding terms, claim notification mechanics, premium remittance schedule, attachment point (currently P20 of deficit distribution per v14c actuarial review).

**Scope:** LMI layer and tail-risk reinsurance layer defined separately. Premium calculation, upfront charge mechanics, claim notification on deficit events at maturity, reinsurer attachment and cession terms.

**Tests first:** attachment-point tests (P20 of deficit distribution correctly identified per v14c); premium calculation tests (match the actuarial review's $9,600 upfront + $4,863 fair loaded for the Optimised base); policy lifecycle tests; stakeholder walkthrough with LMI + reinsurer.

**Build:** policy binding workflow; premium remittance ledger; claim notification pipeline; admin surface: in-force policies, premium history, claim events, reinsurer cession ledger.

**Gate:** LMI provider and reinsurer both countersign the integration test report. Claim notification tested end-to-end against synthetic deficit cases.

**Risk:** reinsurer capacity at the attachment point. Mitigation: actuarial review already documents the attachment economics; present the v14c (Optimised) review to the reinsurer early (week 14) and iterate on attachment if challenged.

### M5 — Broker (weeks 18–24, ~AUD 34k)

**Stakeholder:** Pilot brokers. **Signs off:** broker accreditation process, commission structure, broker portal UX, application handoff mechanics.

**Scope:** distribution. Broker accreditation (who can introduce business), commission accrual and payment schedule, portal for broker-lodged applications, handoff mechanics between broker-initiated and direct-initiated applications.

**Tests first:** accreditation-flow tests; commission-calculation tests (including clawback rules); portal journey tests; stakeholder walkthrough with pilot brokers.

**Build:** broker portal (consistent with the rest of the platform CSS framework); accreditation workflow; commission ledger; broker-scoped admin views.

**Gate:** pilot brokers sign the portal acceptance checklist. Commission calculations reconcile against test scenarios. Dependencies: M2, M3 gate-green.

**Risk:** broker accreditation process is regulatorily sensitive. Mitigation: legal review before build (week 18); accreditation rules are acceptance-tested, not free-form.

### M6 — Consumer + Customer Support (weeks 20–28, ~AUD 44k)

**Stakeholder:** Pilot customers + CS operator(s). **Signs off:** application journey, quote calculator, e-sign flow, statements, dispute flow, support case triage.

**Scope:** the end-to-end customer experience. Application, quote, e-sign, statement view, dispute submission, support case. Plus the CS console: case queue, triage, response templates, escalation to actuary or legal.

**Tests first:** customer-journey tests (quote → application → underwriting → contract → e-sign → settlement); accessibility tests (WCAG 2.1 AA); CS console tests; dispute-flow tests; stakeholder walkthrough with pilot customers (5–10) and CS operators.

**Build:** customer application surface; quote calculator (using the locked v14c Optimised model); e-sign integration; statement renderer; dispute and support case flows; CS console.

**Gate:** 10 pilot customer intents successfully completed through the journey in staging. Pilot CS operator signs the console acceptance checklist. Dependencies: M1–M5 gate-green.

**Risk:** e-sign and ID verification vendor integration. Mitigation: vendor selection in M0; vendor APIs wrapped behind a thin abstraction to allow substitution.

### Admin — cross-cutting (weeks 1–28, ~AUD embedded in milestone costs)

FutureProof Admin is not a single milestone. It evolves through every milestone: M0 ships the skeleton, M1 adds funder views, M2 adds lender views, M3 adds investment views, etc.

Admin is the system of record for ops. It is authenticated, audit-logged, role-based. Every stakeholder group can see their own data; only FutureProof ops sees everything.

By end of M6, Admin covers: funder dashboard, lender dashboard, investment dashboard, insurance dashboard, broker dashboard, customer view, CS console, audit log, deploy-gate status, incident timeline.

## 3. Go-Live Phase (weeks 28–32, ~AUD 35k)

Security, UAT, regulator, pilot. Four workstreams running in parallel.

- **External pen test** — independent firm, scoped to authenticated + unauthenticated app surface + partner integrations. Two weeks. AUD 15k. Remediation plan signed before gate.
- **Code audit + SOC 2 gap analysis** — external security consultant reviews the repo, CI, secrets, access controls. Documents the SOC 2 Type I gap (we will not be SOC 2 certified at pilot, but we need to know the gap). AUD 10k.
- **APRA / IRAP gap analysis** — documents the gap to APRA CPS 234 and IRAP readiness. Required for the Post-Live migration trigger decision. AUD 8k.
- **Stakeholder UAT** — one formal UAT round per stakeholder group. Fail criteria are documented; pass criteria are documented; sign-off is written.
- **Regulatory pack** — PDS, TMD, responsible-lending policy, disclosure documents. Filed.
- **Pilot cohort origination** — 5–10 mortgages through the live system. Paired origination (CTO + BA each oversees every case). Monthly reporting established.

Go-Live Gate: all seven stakeholder milestones gate-green, all four workstreams clean, board signs pilot go/no-go in writing.

## 4. Post-Live — Operate & Evolve

The plan does not end at pilot origination. The Post-Live phase is named, budgeted, and governed. Run-rate ~AUD 200–240k/year for the 2-person team plus external retainers and infrastructure.

### 4.1 Release cadence

Two lanes:

- **Monthly release** — the default. All non-emergency feature work, bug fixes, stakeholder-requested changes. Lane cadence: 3 weeks build + 1 week release (soak on staging, gate checks, release tag, deploy, smoke).
- **Emergency hotfix** — the exception. Used only for security or money-flow defects. Expedited gate path (G1–G5 still mandatory, G6 sign-off compressed to same-day). On-call engineer authors the fix; second person (CTO or BA, whoever is not on-call) signs.

### 4.2 Feature pipeline

New feature requests from any stakeholder go through the same scope → test → build loop as the original build. Features are sized by stakeholder group, prioritised quarterly by the board, and budgeted against the Post-Live run-rate. No stakeholder feature enters build without a signed scope brief. This is how the discipline of the stakeholder-gated MVP is preserved after go-live.

### 4.3 Change control for partner contracts

BlackRock, the lender, the reinsurer, and the e-sign vendor each have API contracts. When a partner announces a breaking change, the process is:

1. Partner announces deprecation (typically 90 days notice).
2. Engineer builds against the new contract in a feature branch. Fake is updated in lock-step.
3. Contract tests green on the new contract; old contract tests still green until cutover.
4. Cutover scheduled in the monthly release lane, coordinated with partner.

Contract changes are a named event; they are not rolled into a general release unless the partner permits.

### 4.4 Model recalibration cycle

The v14c Optimised actuarial model has specific parameter assumptions (μ=9.2%, σ=16.6%, κ=0.163). Those parameters are re-estimated annually via MLE on the latest index-return data. Re-estimation runs as a Python job against the monte_carlo_v14c_optimised.py simulator. The actuary countersigns the re-estimated parameters before they are adopted in the production pricing engine.

Recalibration cycle: January each year. Actuary retainer: ~AUD 8k per cycle.

### 4.5 Security re-certification

- **Annual external pen test** — same firm ideally (continuity). AUD 15k per cycle.
- **Quarterly dependency refresh** — bundler-audit + npm audit + trivy. Clean or patched before the next monthly release.
- **Quarterly access review** — who has production access, who has partner-API credentials, who has admin role. Documented, signed by CTO.
- **Annual SOC 2 re-gap** — track the gap closing quarter by quarter. Full certification is a Series-A project, not Post-Live.

### 4.6 Incident model for a 2-person team

Paired on-call. One primary, one secondary, rotated weekly. External incident escalation retainer with a security consultant (AUD 5k/year retainer). PagerDuty or equivalent for alerts. Runbook maintained alongside the code — a deploy without a runbook update for a new surface fails CI.

Incident classes:
- **P1 (money-flow)** — funder drawdown fails, investment order fails, payment missed. Same-day response. Both engineers on the incident.
- **P2 (stakeholder-facing)** — customer cannot complete application, broker cannot lodge, admin cannot view. Same-day response.
- **P3 (internal)** — observability gap, non-urgent defect, documentation drift. Next-release response.

### 4.7 Infrastructure migration trigger

Fly.io is the correct choice for Foundation → pilot. AWS ap-southeast-2 is the correct choice at scale. The migration is not time-triggered; it is event-triggered, and the event is: **the first wholesale-funder or reinsurer due-diligence questionnaire that requests IRAP attestation or APRA CPS 234 alignment evidence.** That questionnaire typically lands after the first 20–50 mortgages are live and the counterparty is scaling its exposure. Until that point, Fly.io + Cloudflare is fit for purpose.

Migration is a named Post-Live project. ~6–8 weeks. ~AUD 45k (engineer time + AWS setup + IRAP-aligned architecture review + DNS cutover). Budgeted separately from the run-rate, triggered on the event.

See section 6 for the full Fly.io assessment.

## 5. AI Leverage Across Business Operations

The same AI-first posture that drives delivery also drives the back office. Post-live, AI is a cost lever on every non-engineering function. We do not eliminate any of these functions — regulation, counterparties, and customers each require a human accountable — but we staff each function lighter than an equivalent financial-services business of our volume, because the human in each seat operates with AI as a force multiplier. The run-rate numbers in section 7 are calibrated on this assumption; the numbers below are the *implicit saving* versus a conventional staffing model.

### 5.1 Finance

- **Reconciliations drafted by AI, signed by finance.** Daily funder reconciliation, monthly investment-partner NAV reconciliation, quarterly reinsurer cession reconciliation — each runs as a scripted pipeline that produces a draft variance report plus the exceptions-only narrative. Finance spends time on exceptions, not tabulation.
- **Month-end pack drafted by AI.** P&L, balance sheet, funder utilisation, investment performance, insurance premium flow — drafted from the ledger, reviewed by the CFO-contractor retainer, signed by the CTO.
- **Budget vs actual variance analysis** drafted in minutes, not days.
- **Saving vs conventional model:** ~0.6 FTE of junior finance + ~0.3 FTE of senior finance review displaced by AI draft + contractor review. Estimated saved run-rate: ~AUD 90k / yr.

### 5.2 Operations

- **Monitoring triage.** Alerts routed through an AI classifier that summarises the event, cross-references the runbook, and produces a suggested action before paging a human. Human acks and acts; AI pre-digest compresses MTTR.
- **Runbook maintenance.** Runbook deltas drafted by AI from the CI diff, reviewed and merged by the CTO. No deploy lands without a runbook update; AI removes the tax that usually breaks this rule.
- **Vendor contract review.** BlackRock, funder, reinsurer, e-sign, ID verification — contract amendments are triaged by AI (change summary, risk flags, redline) before legal spends any billable hours.
- **Saving vs conventional model:** ~0.5 FTE of a dedicated ops coordinator. Estimated saved run-rate: ~AUD 60k / yr.

### 5.3 Customer Support

- **AI-first tier-1.** Tier-1 responses drafted, routed, and sent with a human CS operator signing. Complex cases escalated to actuary or legal with AI precedent search attached.
- **Case triage.** Incoming cases auto-classified (product question / servicing / dispute / complaint) with suggested response template; CS operator edits and sends.
- **Dispute drafting.** AI drafts the initial response packet (customer history, contract terms, actuarial context) for CS to review, so operators spend time on judgment, not search.
- **Saving vs conventional model:** pilot-phase CS can run with ~0.5 FTE instead of ~1.5 FTE for an equivalent volume. Estimated saved run-rate: ~AUD 80k / yr.

### 5.4 Marketing & Stakeholder Communications

- **Stakeholder decks** (board updates, funder reports, broker packs) drafted by AI from the underlying data; the BA edits the narrative and numbers.
- **Broker explainer materials** — FAQ updates, scenario walk-throughs, PDS-compliant marketing pages — drafted and compliance-checked against the legal glossary before human review.
- **Content pipeline** — blog, LinkedIn, media pitch — drafted by AI, human sign-off enforced by the same CSP-strict publish path as the rest of the app.
- **Saving vs conventional model:** ~0.4 FTE of content/marketing displaced by AI draft + BA edit. Estimated saved run-rate: ~AUD 55k / yr.

### 5.5 Where AI is explicitly *not* the answer

- Regulator-facing filings (PDS, TMD, RG 271 compliance statements) — drafted by legal, not AI.
- Underwriting decisions — deterministic rule-matrix; AI has no role in go/no-go on a specific mortgage.
- Model recalibration — actuary signs the parameter update; AI drafts the commentary only.
- Incident P1 communications — human author, human sign, no AI drafting on money-flow incidents.

### 5.6 Total implied operating saving

At steady state, we estimate AI leverage across finance, operations, customer support, and marketing saves approximately **AUD 285k / year** versus a conventional staffing posture for a financial-services business of pilot size. That saving is the reason the Post-Live run-rate in section 7 is two-person rather than five-person. It is an *assumption* until operated; we commit to revisit the number at month 6 post-live and report the actual delta to the board.

## 6. Infrastructure — Fly.io for financial services

Direct answer: **Fly.io is the right partner for the MVP and pilot. It is not the right partner at scale. The migration trigger is event-based, not time-based.**

### 6.1 Why Fly.io is fine for the MVP

- SOC 2 Type II compliant
- Sydney region (syd) available — data residency controllable at the application level
- Proven at our volume with the web framework and database we run on
- Fast rollback (`fly releases rollback`) — important for a 2-person team
- Low ops burden — a 2-person team cannot operate a full AWS estate without dedicated DevOps
- Pricing is transparent and cheap at pilot scale (dozens of mortgages, not thousands)

Pair with:
- **Cloudflare** in front of Fly.io for WAF, DDoS, rate-limit, bot mitigation, and a stable edge IP for partner-allowlisting
- **AWS S3** (already in use) for backups and document storage — gives a credible exit ramp
- **1Password / Doppler** for secret management outside the repo

### 6.2 Why Fly.io is not right at scale

- No APRA CPS 234 attestation
- No IRAP rating
- Wholesale-funder due diligence under APRA CPS 231 (material outsourcing) will demand enterprise-grade hosting once the book is material — typically after the first 20–50 mortgages
- Limited enterprise networking primitives (no PrivateLink-equivalent, limited VPC isolation) vs AWS ap-southeast-2
- Limited data-residency contractual controls compared to AWS's enterprise agreements
- Reinsurer due-diligence is similar — the moment the reinsurer wants evidence of the underlying hosting's compliance posture, Fly.io becomes the conversation problem, not the technology problem

### 6.3 Migration plan (budgeted, not executed at MVP)

The migration itself is not difficult. The platform has no Fly-specific primitives beyond the deploy command and secrets. Migration scope:

1. IRAP-aligned architecture review (independent consultant) — 1 week, ~AUD 8k
2. AWS ap-southeast-2 VPC + ECS/Fargate + managed database + CloudFront setup — 2 weeks, engineer
3. Dual-running period with cutover testing on staging — 2 weeks
4. DNS cutover with rollback plan — 1 day
5. Post-cutover monitoring + Fly.io decommission — 1 week

Total: 6–8 weeks, ~AUD 45k. Triggered on the first counterparty questionnaire, not on a calendar date. Named in the Post-Live budget as a separate line.

## 7. Costs & Capital Ask

External legal (contracts, PDS, broker accreditation, funder agreements, AFSL / ACL work) is governed by a separate legal budget and does not appear below.

### 7.1 Build budget

| Line item | Amount (AUD) | Notes |
|---|---|---|
| CTO (30 wks @ 160k annualised) | 92,000 | Market-rate CTO |
| BA / Programmer (30 wks @ 140k × 0.8 FTE) | 65,000 | Scope-test-build per stakeholder is BA-intensive |
| External actuary (4 reviews: M3, M4, Go-Live, Post-Live kickoff) | 22,000 | |
| Security (pen test 15k + SOC 2 gap 10k + APRA/IRAP gap 8k) | 33,000 | |
| Auditor retainer (pilot period) | 8,000 | |
| Hardware (laptops, dev kit, HSM-grade token) | 15,000 | 2× dev machines + YubiKeys + ergonomic setup |
| Infrastructure (Fly.io + Cloudflare + monitoring + AWS backup) | 5,000 | |
| Tooling SaaS (CI, e-sign, ID verification, error tracking) | 4,000 | |
| AI/LLM spend (Claude API for BA workflow) | 4,000 | |
| **Subtotal** | **248,000** | |
| Contingency (15%) | 37,000 | |
| **Total with contingency** | **285,000** | Headline: ~AUD 285k (legal separate) |

### 7.2 Post-Live annualised run-rate (separate, not bundled into headline)

| Line item | Annual (AUD) |
|---|---|
| CTO (full year) | 160,000 |
| BA / Programmer (0.8 FTE) | 112,000 |
| External actuary (annual recalibration) | 8,000 |
| Annual pen test | 15,000 |
| Infrastructure | 12,000 |
| Tooling SaaS | 8,000 |
| AI/LLM spend | 8,000 |
| Cyber + PI insurance | 12,000 |
| **Total annualised** | **~335,000 (range 325–360k)** |

**Implied operating saving via AI leverage** (section 5): ~AUD 285k / yr versus a conventional staffing model — the reason the Post-Live line is two-person, not five. Legal retainer sits in the separate legal budget.

### 7.3 Capital ask (build + 12-month runway)

| Layer | Amount (AUD) | Purpose |
|---|---|---|
| Build budget (row-total from 7.1) | 285,000 | 30-week delivery to pilot-live |
| Post-Live — Year 1 run-rate | 335,000 | Two-person team + infra + insurance + recertification |
| Infrastructure migration reserve (Fly.io → AWS) | 45,000 | Event-triggered; held in reserve, not drawn at day 1 (§6.3) |
| Operational / regulatory contingency buffer | 35,000 | ~5% of first three lines — covers AUSTRAC onboarding, unplanned due-diligence rounds |
| **Total capital ask** | **~700,000** | **Runway: build + 12 months post-live + migration cover** |

**Headline capital ask: AUD 700k.** Build + one year post-live + named migration reserve + buffer. Legal is separately budgeted. Any Series-A decision is a separate conversation after pilot completes.

> **Note on scope in PDF companion:** the stakeholder-meeting PDF (`docs/pdfs/FutureProof_EPM_Stakeholder_Gated_Build_Plan_Apr2026.pdf`) additionally includes full sections on Commercial Assumptions, Money-Flow Map (with diagram), Pilot Success KPIs, Scale-Up Path, Business Continuity & Key-Person Risk, Regulatory Pathway (RG 271/256/165/274, AUSTRAC, Privacy/NDB, CDR posture), and Data Governance (residency, encryption, PII tiers, retention, audit, DSR). The PDF is the canonical version for stakeholder distribution.

## 8. Risks & Unknowns

| Risk | Owner | Mitigation |
|---|---|---|
| BlackRock not signed by M3 start (week 11) | BA | Plan-B: domestic managed-account provider via the Investment Partner Interface abstraction. ~4 weeks additional work |
| Wholesale funder not signed by M1 start (week 5) | BA | Approach 3 funders in parallel from week 1. Fake-first architecture means build continues |
| Regulatory surprise (PDS, TMD, responsible lending) | BA + Legal | External legal engaged week 1; informal regulator approach before formal filing |
| Reinsurer rejects P20 attachment | Actuary + BA | Present v14c Optimised actuarial review early (week 14); iterate on attachment if challenged |
| Solo-engineer bus factor | CTO | BA is a programmer, not just a liaison; paired on-call; external code review at each gate |
| Scope creep from signed briefs | BA | Signed briefs are immutable; changes require re-sign; budget 3 rounds per milestone |
| Infrastructure migration triggered mid-pilot | CTO | Named project, pre-priced, pre-scoped. Execute in the 6–8 week window without blocking new origination |
| AI code quality regression | CTO + BA | CTO reviews every BA-generated PR; contract tests and acceptance tests are authoritative, not AI suggestions |

## 9. Go / no-go criteria for pilot

All of:

- All seven stakeholder milestones gate-green.
- External pen test clean or remediated.
- SOC 2 + APRA/IRAP gap documents filed and reviewed by board.
- PDS + TMD filed.
- 5–10 pilot customer intents signed.
- Funder, BlackRock (or Plan-B), LMI, reinsurer, and pilot brokers all countersigned their integration test reports.
- CTO and BA both recommend go in writing.
- Board approves in writing.

Any red is no-go. No exceptions.

## Appendix A — Companion document

- **v14c Optimised Actuarial Review (April 2026)** — the model that pricing, LMI attachment, and reinsurance cession inherit from. Every model-fidelity test in this plan pins to its locked output.

End of document.
