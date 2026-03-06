# FutureProof EPM — Execution Plan

**Created:** 2026-03-06  
**Purpose:** Break the REFACTOR_PROMPT into small, token-managed steps  
**Rule:** No step exceeds 15K tokens. Each step produces a commit. Each step is independently runnable.

---

## How to Use This Plan

1. Start a fresh session for each group (or when context > 70%)
2. Say: **"Step X.Y"** — the agent reads REFACTOR_PROMPT.md + this file and executes
3. Each step ends with a git commit
4. Mark steps done as you go: `- [x]`
5. If a step runs long, stop, commit what's done, note progress here

---

## Step Summary

| Step | Task | Tokens | Depends On |
|------|------|--------|-----------|
| 0.1 | Security hardening (Devise + InputSanitization) | 8K | — |
| 0.2 | Field-level encryption (L4 data) | 8K | — |
| 0.3 | ReferralPartner model + migration | 8K | — |
| 0.4 | InvestmentPartner model + migration | 8K | — |
| 0.5 | AU seed ecosystem (funders, lenders, brokers, consumers) | 12K | 0.3, 0.4 |
| 0.6 | US seed ecosystem (funders, lenders, brokers, consumers) | 12K | 0.3, 0.4 |
| 1.1 | Rails/Ruby upgrade | 5K | — |
| 1.2 | Multi-region routing (already partly done — audit & fix) | 8K | 1.1 |
| 1.3a | Test suite audit — identify failures | 5K | 1.1 |
| 1.3b | Test suite audit — fix failures (batch 1) | 10K | 1.3a |
| 1.3c | Test suite audit — fix failures (batch 2) | 10K | 1.3b |
| 2.1a | Calculation engine — CPI escalation + inflation scenarios | 10K | 1.1 |
| 2.1b | Calculation engine — NNEG calculation + Model B structure | 10K | 2.1a |
| 2.1c | Calculation engine — FX sensitivity + regional quotes | 10K | 2.1b |
| 2.2a | Contracts — AU mortgage contract + NNEG clause | 12K | 1.2 |
| 2.2b | Contracts — US mortgage contract + disclosures | 12K | 1.2 |
| 2.2c | Contracts — NZ + UK contracts | 12K | 1.2 |
| 2.2d | Contracts — beneficiary letter templates (all regions) | 8K | 2.2a |
| 2.2e | Contracts — privacy policies + terms (all regions) | 12K | 1.2 |
| 2.3a | AI Chat — models + routing service | 10K | 1.2 |
| 2.3b | AI Chat — UI component + Stimulus controller | 10K | 2.3a |
| 2.3c | AI Chat — regional awareness + mock responses | 8K | 2.3b |
| 2.4a | Agent dashboard — models + seed data | 8K | — |
| 2.4b | Agent dashboard — view + Stimulus auto-refresh | 10K | 2.4a |
| 3.1a | Mobile responsive — homepage + calculator + nav | 10K | — |
| 3.1b | Mobile responsive — application form + dashboards | 10K | 3.1a |
| 3.2a | Design system — CSS variables + typography + colours | 8K | — |
| 3.2b | Design system — components (buttons, cards, inputs, alerts) | 10K | 3.2a |
| 3.3 | Accessibility audit + critical fixes | 8K | 3.2b |
| 4.1a | Integration tests — quote → application → approval flow | 12K | 2.1c |
| 4.1b | Integration tests — lender dashboard → review → contract | 12K | 2.2a |
| 4.1c | Integration tests — funder + admin + email workflows | 12K | 4.1b |
| 4.1d | Integration tests — multi-region compliance checks | 10K | 4.1c |
| 4.2a | Unit tests — models (batch 1: User, Application, Contract) | 10K | — |
| 4.2b | Unit tests — models (batch 2: Lender, Funder, Pool) | 10K | — |
| 4.2c | Unit tests — services (CalculationEngine, AiAgentRouter) | 10K | 2.1c, 2.3a |
| 4.3 | Production readiness checklist — verify all items | 5K | 4.1d, 4.2c |
| 5.1a | Capabilities document — sections 1-5 | 8K | 4.3 |
| 5.1b | Capabilities document — sections 6-10 | 8K | 5.1a |
| 5.3 | Deployment checklist (update existing) | 3K | 5.1b |
| 6.1 | Code quality — RuboCop + Brakeman + dead code | 5K | All |
| 6.2 | Performance — indexes + caching + compression | 8K | All |

**Total: 42 steps, ~370K tokens estimated (sequential)**

---

## Detailed Steps

### Phase 0: Foundation & Security

#### Step 0.1 — Security Hardening (Devise + InputSanitization)
- [x] Re-enable `InputSanitization` on User model (uncomment include)
- [x] Enable Devise `:lockable` — add migration for `failed_attempts`/`locked_at`/`unlock_token` columns
- [x] Confirmable already present — `confirmed_at`/`confirmation_token` columns exist
- [x] Enable Devise `:trackable` — add migration for `sign_in_count`/`current_sign_in_at`/`last_sign_in_at`/IPs
- [x] Strengthen password: `config.password_length = 10..128`, User model minimum 10
- [x] Update Devise initializer: lock_strategy, unlock_strategy(:both), max 5 attempts, 30min lockout, last_attempt_warning
- [x] Run tests, commit (c61c8c7)

#### Step 0.2 — Field-Level Encryption
- [x] Add `encrypts :government_id, :credit_score, :bank_account_number` to Application model
- [x] Generated encryption keys via `rails db:encryption:init`, added to credentials
- [x] Test encryption round-trip — verified data encrypted at rest, decrypted on read
- [x] Run tests, commit (72a74f6)

#### Step 0.3 — ReferralPartner Model
- [x] Generated ReferralPartner model with all fields
- [x] belongs_to :lender, has_many :applications (added referral_partner_id FK to applications)
- [x] Validations: name, region, licence_number (unique per region), commission_rate, email format
- [x] PaperTrail + InputSanitization enabled
- [x] 12 model tests passing
- [x] Commit (e3c760d)

#### Step 0.4 — InvestmentPartner Model
- [x] Generated InvestmentPartner model (name, region, licence_number, aum, portfolio_strategy, fee_rate, status)
- [x] belongs_to :wholesale_funder (direct FK)
- [x] Validations: name, region, licence_number (globally unique), aum/fee_rate numeric ranges
- [x] PaperTrail + InputSanitization enabled
- [x] 11 model tests passing
- [x] Commit (c93a6ca)

#### Step 0.5 — AU Seed Ecosystem
- [ ] Create `db/seeds/regional_ecosystem_au.rb`
- [ ] Seed FutureProof Financial AU (lender), FutureProof Capital AU (investment partner)
- [ ] Seed 2 brokers (Helen Chen, James Wright) linked to lenders
- [ ] Seed 5 AU consumers with Users, Applications (various stages), MortgageContracts
- [ ] Link consumers to lenders, funder pools, brokers
- [ ] Realistic AU property values, addresses, phone formats
- [ ] Test with `rails db:seed` (dev only), commit

#### Step 0.6 — US Seed Ecosystem
- [ ] Create `db/seeds/regional_ecosystem_us.rb`
- [ ] Seed Vanguard Institutional (wholesale funder), FutureProof Financial US (lender), Pacific Coast Lending
- [ ] Seed FutureProof Capital US (investment partner)
- [ ] Seed 2 US brokers (Sarah Johnson, Michael Torres)
- [ ] Seed 5 US consumers with Users, Applications, MortgageContracts
- [ ] Realistic US property values, addresses, phone formats, state assignments (FL, CA, AZ, NY)
- [ ] Test with `rails db:seed`, commit

---

### Phase 1: Infrastructure

#### Step 1.1 — Rails/Ruby Upgrade
- [ ] Update Gemfile: `gem "rails", "~> 8.1.2"`
- [ ] Update `.ruby-version` to latest stable 3.4.x
- [ ] `bundle update rails`
- [ ] Fix deprecation warnings
- [ ] Run full test suite
- [ ] Commit

#### Step 1.2 — Multi-Region Routing Audit
- [ ] Verify `config/regions.yml` has all 4 regions (already exists)
- [ ] Verify `RegionHelper` works for /, /au, /nz, /uk routes
- [ ] Add region detection to quote engine output
- [ ] Add region to Application model if missing
- [ ] Test all region paths respond correctly
- [ ] Commit

#### Step 1.3a — Test Suite Audit (Identify)
- [ ] Run `rails test` — capture full output
- [ ] Categorise failures: missing models, fixture issues, CSP, integration
- [ ] Create `docs/TEST_FAILURES.md` with categorised list
- [ ] Commit

#### Step 1.3b — Test Suite Fix (Batch 1)
- [ ] Fix model test failures
- [ ] Fix fixture issues
- [ ] Re-run, document remaining
- [ ] Commit

#### Step 1.3c — Test Suite Fix (Batch 2)
- [ ] Fix controller test failures
- [ ] Fix integration test failures
- [ ] Target: >80% passing
- [ ] Commit

---

### Phase 2: Core Platform

#### Step 2.1a — Calculation Engine: CPI + Inflation
- [ ] Add CPI escalation to `CalculationEngine` (annual adjustment, 4% cap)
- [ ] Add inflation scenario projections (low 1%, base 2.5%, high 5%)
- [ ] Quote output includes 5/10/15/20 year income projections under each scenario
- [ ] Write tests for CPI adjustment logic
- [ ] Commit

#### Step 2.1b — Calculation Engine: NNEG + Model B
- [ ] Add NNEG calculation (mortgage balance vs property value at each year)
- [ ] Model B structure: income = loan advances, not portfolio distributions
- [ ] Add NNEG trigger probability to quote output
- [ ] Add estate impact projection (property + portfolio - mortgage = estate)
- [ ] Write tests
- [ ] Commit

#### Step 2.1c — Calculation Engine: FX + Regional Quotes
- [ ] Add FX sensitivity for non-US regions (±10%, ±20% scenarios)
- [ ] Regional currency formatting in quote output
- [ ] AU: Add Centrelink impact estimate (assets test, deeming)
- [ ] UK: Add IHT impact estimate
- [ ] Write tests for regional calculations
- [ ] Commit

#### Step 2.2a — Contracts: AU Mortgage + NNEG
- [ ] Create `app/views/legal/contracts/mortgage_contract_au.html.erb`
- [ ] Include NNEG clause (standard wording)
- [ ] Include advised sales acknowledgement
- [ ] Include Centrelink disclosure
- [ ] Test renders correctly
- [ ] Commit

#### Step 2.2b — Contracts: US Mortgage + Disclosures
- [ ] Create `app/views/legal/contracts/mortgage_contract_us.html.erb`
- [ ] Include TILA/RESPA disclosures
- [ ] Include non-recourse/NNEG clause
- [ ] Include "loan proceeds not taxable" disclosure
- [ ] Include state-specific sections (CA, FL, AZ, NY)
- [ ] Commit

#### Step 2.2c — Contracts: NZ + UK
- [ ] Create NZ mortgage contract (CCCFA compliant, relationship property consent)
- [ ] Create UK mortgage contract (MCOB compliant, ERC standards, IHT disclosure)
- [ ] Both include NNEG clause
- [ ] Commit

#### Step 2.2d — Beneficiary Letter Templates
- [ ] Create `app/views/legal/beneficiary/` directory
- [ ] AU template (no estate tax, CGT note, settlement process)
- [ ] US template (step-up basis, NNEG, refinance option)
- [ ] NZ template (no estate tax, relationship property note)
- [ ] UK template (IHT implications, ERC settlement standards, RNRB note)
- [ ] Commit

#### Step 2.2e — Privacy Policies + Terms
- [ ] Create privacy policies for AU (Privacy Act), US (state laws), NZ (Privacy Act 2020), UK (GDPR)
- [ ] Create customer terms for each region
- [ ] Link from footer
- [ ] Commit

#### Step 2.3a — AI Chat: Models + Routing
- [ ] Verify/create `ChatConversation`, `ChatMessage`, `ChatAgent` models
- [ ] Create/update `AiAgentRouter` service with region-aware routing
- [ ] 5 agent types: Onboarding, Loan Specialist, Legal, Technical Support, Operations
- [ ] Write model tests
- [ ] Commit

#### Step 2.3b — AI Chat: UI + Stimulus
- [ ] Create floating chat widget (bottom-right, all customer pages)
- [ ] Stimulus controller for open/close, send message, display response
- [ ] Mobile responsive (full-screen on mobile)
- [ ] CSS in design_system.css (no inline styles)
- [ ] Commit

#### Step 2.3c — AI Chat: Regional Awareness
- [ ] Mock response dataset per agent type (20+ responses each)
- [ ] Region-aware responses (AU legislation/currency, US legislation/currency, etc.)
- [ ] Agents never expose portfolio details (Model B — consumer doesn't own it)
- [ ] Log all conversations
- [ ] Commit

#### Step 2.4a — Agent Dashboard: Models + Seeds
- [ ] Verify/create `AgentPerformance`, `AgentTask` models
- [ ] Seed 8 agents (mix of AI + human, various roles)
- [ ] Seed 50+ completed tasks with realistic timestamps
- [ ] Seed performance metrics (resolution time, satisfaction, escalation rate)
- [ ] Commit

#### Step 2.4b — Agent Dashboard: View + Live Updates
- [ ] Create admin dashboard view with agent grid
- [ ] Cards: status, tasks completed, avg resolution time, NPS
- [ ] Stimulus controller for auto-refresh (every 10 seconds)
- [ ] Live activity stream (recent completions)
- [ ] CSS status indicators (green/amber/red)
- [ ] Commit

---

### Phase 3: UX & Mobile

#### Step 3.1a — Mobile: Homepage + Calculator + Nav
- [ ] Audit homepage on 375px
- [ ] Fix navigation (hamburger menu on mobile)
- [ ] Fix calculator layout (single column, large touch targets)
- [ ] Fix hero section
- [ ] Commit

#### Step 3.1b — Mobile: Application Form + Dashboards
- [ ] Fix multi-step application form (single column on mobile)
- [ ] Fix customer dashboard
- [ ] Fix admin dashboard (sidebar collapses)
- [ ] Test on 375px, 768px, 1024px, 1440px
- [ ] Commit

#### Step 3.2a — Design System: Variables + Typography
- [ ] Create/update `design_system.css` with CSS variables
- [ ] Typography scale (SF Pro stack, 32/24/20/16/14px)
- [ ] Colour palette (primary navy, accent, status colours)
- [ ] 8px spacing grid
- [ ] Commit

#### Step 3.2b — Design System: Components
- [ ] Buttons (primary, secondary, destructive, sizes)
- [ ] Cards (standard, stat, interactive)
- [ ] Form inputs (text, select, textarea, checkbox, radio)
- [ ] Alerts (info, success, warning, error)
- [ ] Badges (status indicators)
- [ ] Tables (admin-table styling)
- [ ] Commit

#### Step 3.3 — Accessibility
- [ ] Run axe DevTools audit on key pages
- [ ] Fix colour contrast violations (4.5:1 text, 3:1 UI)
- [ ] Add missing ARIA labels
- [ ] Ensure keyboard navigation (no tab traps)
- [ ] Add focus indicators
- [ ] Fix semantic HTML issues
- [ ] Commit

---

### Phase 4: Testing

#### Step 4.1a — Integration: Quote → Application → Approval
- [ ] System test: visitor calculates quote, creates account, submits application
- [ ] Test: admin reviews application, approves, contract generated
- [ ] Test: customer sees active EPM on dashboard
- [ ] Commit

#### Step 4.1b — Integration: Lender Dashboard
- [ ] System test: lender logs in, views pending applications
- [ ] Test: lender reviews, approves/rejects
- [ ] Test: contract generation and customer notification
- [ ] Commit

#### Step 4.1c — Integration: Funder + Admin + Email
- [ ] System test: funder views portfolio, pool allocation
- [ ] Test: admin creates email workflow
- [ ] Test: workflow triggers correctly
- [ ] Commit

#### Step 4.1d — Integration: Multi-Region
- [ ] Test: AU site shows AU contracts, currency, disclosures
- [ ] Test: US site shows US contracts, currency, disclosures
- [ ] Test: region switching works
- [ ] Commit

#### Step 4.2a — Unit Tests: Core Models (Batch 1)
- [ ] User model tests (validation, authentication, roles)
- [ ] Application model tests (state machine, associations)
- [ ] MortgageContract model tests (calculations, status)
- [ ] Commit

#### Step 4.2b — Unit Tests: Business Models (Batch 2)
- [ ] Lender model tests
- [ ] WholesaleFunder + FunderPool tests
- [ ] ReferralPartner + InvestmentPartner tests
- [ ] Commit

#### Step 4.2c — Unit Tests: Services
- [ ] CalculationEngine tests (CPI, NNEG, FX, regional)
- [ ] AiAgentRouter tests (routing, region-awareness)
- [ ] QuoteService tests
- [ ] Commit

#### Step 4.3 — Production Readiness Checklist
- [ ] Run through every item in DEPLOYMENT_CHECKLIST.md
- [ ] Verify CSP compliance (`bin/rails csp:report`)
- [ ] Verify mobile renders
- [ ] Verify all legal pages present
- [ ] Document any remaining issues
- [ ] Commit

---

### Phase 5: Documentation

#### Step 5.1a — Capabilities Document (Part 1)
- [ ] Executive summary, product architecture, tech stack
- [ ] Security & compliance summary (from Phase 0A)
- [ ] Multi-region support overview
- [ ] Commit

#### Step 5.1b — Capabilities Document (Part 2)
- [ ] Integration points (mocked)
- [ ] Agent-driven operations
- [ ] Financial model summary
- [ ] User journeys
- [ ] Future roadmap
- [ ] Commit

#### Step 5.3 — Deployment Checklist Update
- [ ] Update existing DEPLOYMENT_CHECKLIST.md with Phase 0A findings
- [ ] Add security hardening verification steps
- [ ] Add regional compliance verification steps
- [ ] Commit

---

### Phase 6: Cleanup

#### Step 6.1 — Code Quality
- [ ] Run RuboCop, fix critical issues
- [ ] Run Brakeman, fix security warnings
- [ ] Remove dead code
- [ ] Commit

#### Step 6.2 — Performance
- [ ] Add database indexes on frequently queried columns
- [ ] Add caching for quote calculations
- [ ] Enable gzip compression
- [ ] Verify page load <3s desktop, <5s mobile
- [ ] Commit

---

## Session Planning Guide

Each session should tackle 2-4 steps (depending on complexity). Suggested groupings:

| Session | Steps | Est. Tokens | Focus |
|---------|-------|-------------|-------|
| A | 0.1, 0.2 | 16K | Security hardening |
| B | 0.3, 0.4 | 16K | New models |
| C | 0.5, 0.6 | 24K | Seed data |
| D | 1.1, 1.2 | 13K | Infrastructure |
| E | 1.3a, 1.3b | 15K | Test fixes batch 1 |
| F | 1.3c | 10K | Test fixes batch 2 |
| G | 2.1a, 2.1b | 20K | Calculation engine core |
| H | 2.1c | 10K | Calculation engine regional |
| I | 2.2a, 2.2b | 24K | AU + US contracts |
| J | 2.2c, 2.2d | 20K | NZ/UK contracts + beneficiary |
| K | 2.2e | 12K | Privacy + terms |
| L | 2.3a, 2.3b | 20K | Chat system |
| M | 2.3c, 2.4a | 16K | Chat regional + agent models |
| N | 2.4b | 10K | Agent dashboard UI |
| O | 3.1a, 3.1b | 20K | Mobile responsive |
| P | 3.2a, 3.2b | 18K | Design system |
| Q | 3.3 | 8K | Accessibility |
| R | 4.1a, 4.1b | 24K | Integration tests 1 |
| S | 4.1c, 4.1d | 22K | Integration tests 2 |
| T | 4.2a, 4.2b | 20K | Unit tests |
| U | 4.2c, 4.3 | 15K | Service tests + readiness |
| V | 5.1a, 5.1b, 5.3 | 19K | Documentation |
| W | 6.1, 6.2 | 13K | Cleanup |

**Total: ~23 sessions, ~370K tokens**

---

## Progress Tracker

Mark steps complete as they're done:

```
Phase 0: [x] 0.1  [x] 0.2  [x] 0.3  [x] 0.4  [ ] 0.5  [ ] 0.6
Phase 1: [ ] 1.1  [ ] 1.2  [ ] 1.3a [ ] 1.3b [ ] 1.3c
Phase 2: [ ] 2.1a [ ] 2.1b [ ] 2.1c [ ] 2.2a [ ] 2.2b [ ] 2.2c [ ] 2.2d [ ] 2.2e
         [ ] 2.3a [ ] 2.3b [ ] 2.3c [ ] 2.4a [ ] 2.4b
Phase 3: [ ] 3.1a [ ] 3.1b [ ] 3.2a [ ] 3.2b [ ] 3.3
Phase 4: [ ] 4.1a [ ] 4.1b [ ] 4.1c [ ] 4.1d [ ] 4.2a [ ] 4.2b [ ] 4.2c [ ] 4.3
Phase 5: [ ] 5.1a [ ] 5.1b [ ] 5.3
Phase 6: [ ] 6.1  [ ] 6.2
```
