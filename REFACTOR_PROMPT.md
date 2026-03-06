# FutureProof EPM Platform — Complete Refactoring Prompt

**Version:** 1.0  
**Created:** 2026-03-04  
**Target:** Production-Ready, VC-Demonstrable State  
**Timeline:** Phased delivery, minimal token waste  
**Deployment:** Multi-region (AU, NZ, UK, US) with geo-routing

---

## EXECUTIVE BRIEF

**Mission:** Refactor FutureProof into a fully-formed, launch-ready SaaS platform for Equity Preservation Mortgages (EPMs). The system must be agent-managed, multi-region compliant, thoroughly tested, and ready to demo to venture capitalists.

**Scope:** Not a complete rebuild—the Rails 8 foundation exists. We're:
1. Upgrading to latest Rails/Ruby
2. Filling in missing sections (contracts, compliance, localization)
3. Adding modern UX and mobile support
4. Implementing AI-driven agent systems for business operations
5. Creating example data and mocked external integrations
6. Preparing comprehensive security & capabilities documentation

**Success Criteria:**
- ✅ All core features functionally complete (no placeholders)
- ✅ Multi-region support with proper compliance contracts
- ✅ Mobile-responsive, modern UX (Apple HIG standards)
- ✅ 80%+ test coverage with integration tests passing
- ✅ Agent-driven dashboards (real-time performance mockups)
- ✅ AI Chat system with role-appropriate agents
- ✅ Production-grade security documentation
- ✅ Can launch tomorrow if external APIs go live

---

## PHASE 0: SETUP & CRITICAL RULES

### 🔴 DATA SAFETY (ZERO TOLERANCE)

**NEVER EVER:**
- Run `rails db:drop`, `rails db:reset`, `rails db:setup` without explicit permission
- Truncate, delete, or modify production data
- Drop tables or columns in destructive migrations
- Execute SQL `DELETE`, `TRUNCATE`, or `DROP` without asking first

**ALWAYS ASK PERMISSION FOR:**
- Any database schema changes
- Data modification operations
- Seeds that overwrite existing data
- Database connection changes

This is non-negotiable. Data loss = project failure.

### 🚨 DEPLOYMENT SAFETY CHECKS

**BEFORE DEPLOYING TO FLY.IO — MANDATORY CHECKLIST:**
```bash
# 1. Verify Fly.io login
fly auth whoami
# Should show: <correct-user-email>

# 2. Verify app context
fly status
# Should show: futureproof-epm-platform (or correct app name)

# 3. Check target environment
echo $FLY_API_TOKEN | head -c 10
# Verify it matches your account

# Only after all 3 pass:
fly deploy --remote-only
```

**Wrong login = accidentally overwriting wrong app.** This check is mandatory.

### 🔒 CSP COMPLIANCE (STRICT)

**FORBIDDEN (WILL BREAK IN BROWSERS):**
- ❌ Inline styles: `style="color: red;"`
- ❌ Inline handlers: `onclick="alert('hi')"`
- ❌ Inline scripts: `<script>console.log()</script>`
- ❌ JavaScript URLs: `href="javascript:void(0)"`

**REQUIRED:**
- ✅ All CSS in `/app/assets/stylesheets/`
- ✅ All JS in `/app/javascript/` (Stimulus controllers)
- ✅ Data attributes for interactivity: `data-action="click->controller#method"`
- ✅ Custom classes only: `admin-form-*`, `status-badge`, etc.

**Before every commit:**
```bash
bin/rails csp:report
# Fix ANY violations immediately
```

### 🎨 CSS FRAMEWORK RESTRICTIONS

**THIS PROJECT = 100% CUSTOM CSS. PERIOD.**

**FORBIDDEN:**
- ❌ Tailwind: `text-*`, `bg-*`, `flex`, `grid`, `p-*`, `m-*`, etc.
- ❌ Bootstrap: `btn-primary`, `container`, `row`, `col-*`, etc.
- ❌ ANY external framework classes

**REQUIRED CUSTOM CLASSES:**
- `admin-form-*` (input, select, textarea, group, row, section, container, actions)
- `admin-table`, `admin-btn`, `admin-btn-primary`, `admin-btn-secondary`
- `status-badge`, `status-ok`, `status-complete`, `status-pending`
- `admin-actions-bar`, `admin-search`, `admin-actions`

**Check available classes in:** `/app/assets/stylesheets/admin.css`

---

## PHASE 0A: COMPLIANCE AUDIT & PRODUCT DESIGN (COMPLETED)

**Status:** ✅ ALL 15 WORKS DELIVERED (2026-03-06)  
**Location:** `/docs/` directory  
**Impact:** These findings MUST inform all subsequent phases. Do not build features that contradict compliance requirements.

### Deliverables

| Work | Document | Key Finding |
|------|----------|-------------|
| 1-2 | `compliance/AUSTRALIA_COMPLIANCE.md` | EPM likely classified as credit product (ACL required). ASIC may also require AFSL if investment component emphasised. Centrelink assets test reduces Age Pension — must disclose prominently. |
| 3-4 | `compliance/UK_COMPLIANCE.md` | Lifetime mortgage classification. Advised sales ONLY (no self-serve). NNEG mandatory. ERC membership commercially essential. IHT at 40% is major selling point. |
| 5 | `compliance/NZ_COMPLIANCE.md` | Cleanest jurisdiction — no estate tax, no pension impact, no CGT. FIF tax on offshore ETFs is critical (~$10K/yr if consumer owns portfolio). |
| 6-7 | `compliance/US_COMPLIANCE.md` | SEC risk is #1 threat (Howey test). Structure as loan advances, not investment returns. Tax-free income mirrors HECM. State-by-state licensing. |
| 8 | `SECURITY_FRAMEWORK.md` | InputSanitization disabled on User model. No MFA. No field-level encryption for government IDs. Password minimum only 6 chars. |
| 9 | `TAX_TREATMENT.md` | **Model B (lender owns portfolio) recommended for ALL regions.** Provides tax-free income everywhere, avoids FIF (NZ), avoids Centrelink deeming (AU). |
| 10 | `ESTATE_BENEFITS.md` | EPM is a growing product (unlike traditional ER which depletes). NNEG protects beneficiaries. Middle case: +£422K estate + £600K income consumed. |
| 11 | `EPM_VARIANTS.md` | 5 variants: Standard (Phase 1), Growth, Flex, Protect, Legacy (Phases 2-3). Each has different LTV, portfolio strategy, payout structure. |
| 12 | `INSURANCE_FRAMEWORK.md` | Buildings insurance mandatory. MPI NOT required (NNEG replaces it). NNEG priced as embedded put option. PI + cyber insurance for platform. |
| 13 | `CERTIFICATIONS_ROADMAP.md` | ~$400K one-time + ~$296K/year. 12-month critical path. UK FCA is longest pole (6-12 months). |
| 14 | `INCIDENT_RESPONSE.md` | UK 72-hour ICO deadline governs multi-region breaches. Financial calculation errors need specific protocol — overpayment: don't claw back without legal advice. |
| 15 | `CURRENCY_INFLATION.md` | Full FX hedge too expensive. Income-only hedge recommended. CPI-linked income sustainable 25+ years with 4% annual cap. Deflation is worst-case scenario. |

### Critical Design Decisions (From Phase 0A)

These decisions affect EVERY subsequent phase and must be embedded in the codebase:

1. **Portfolio Ownership: Model B (Lender Owns)**
   - Consumer receives loan advances only — not investment distributions
   - Tax-free income in all 4 regions
   - No FIF tax (NZ), no Centrelink deeming (AU), no 1099 (US), no dividend tax (UK)
   - Platform does NOT show consumer a portfolio dashboard (they don't own it)
   - Lender/SPV entity manages investments

2. **Advised Sales Only (All Regions)**
   - No self-serve EPM purchase flow
   - Consumer must receive independent advice before contract
   - Quote engine is informational — application requires adviser involvement
   - UK: FCA requires this. AU/NZ/US: best practice and likely regulatory expectation

3. **NNEG is Non-Negotiable**
   - Every EPM contract includes No Negative Equity Guarantee
   - Beneficiary letter templates required for estate settlement
   - NNEG pricing built into lender margin (Black-Scholes or equivalent)
   - UK: ERC membership requires it. Other regions: contractual commitment.

4. **CPI-Linked Income (Standard Variant)**
   - Annual adjustment by local CPI (ABS, BLS, Stats NZ, ONS)
   - Cap at 4% p.a. to prevent runaway escalation
   - Sustainability check: if withdrawal rate >3.5%, flag for review
   - Show inflation scenarios in every quote (low/base/high)

5. **Security Hardening (Before Launch)**
   - Re-enable InputSanitization on User model
   - Enable Devise :lockable (5 attempts → 30 min lockout)
   - Enable Devise :confirmable (email verification)
   - Implement MFA for admin roles (devise-two-factor)
   - Field-level encryption for L4 data (government IDs, credit scores)
   - Password minimum: 12 chars admin, 10 chars user

6. **Multi-Region Disclosures**
   - AU: Centrelink impact estimate in every quote
   - US: "Loan proceeds are not taxable income" disclosure
   - NZ: "Does not affect NZ Super" marketing highlight
   - UK: IHT impact calculator in every quote
   - All: "Seek independent tax/financial advice" at quote, application, and contract stages

### Impact on Existing Phases

| Phase | Changes Required |
|-------|-----------------|
| 2.1 (Financial Model) | Add CPI escalation, FX sensitivity, NNEG calculation, Model B structure |
| 2.2 (Contracts) | Include NNEG clause, advised sales requirement, regional disclosures, beneficiary letter templates |
| 2.3 (AI Chat) | Agents must never expose portfolio details (consumer doesn't own it). Region-aware tax/pension guidance. |
| 3.x (UX) | Quote engine shows inflation scenarios, FX sensitivity (non-US), estate impact, Centrelink/IHT estimates |
| 4.x (Testing) | Test NNEG calculations, CPI adjustment logic, regional disclosure presence, Model B income calculation |
| 5.1 (Capabilities) | Incorporate 5 product variants, licensing roadmap, compliance matrix, security framework |

---

## PHASE 1: INFRASTRUCTURE & UPGRADES

### Task 1.1: Rails & Ruby Upgrade
- **Current:** Rails 8.0.2, Ruby 3.3.6
- **Target:** Rails 8.1.x, Ruby 3.4.4 (latest stable)
- **Steps:**
  1. Update Gemfile: `gem "rails", "~> 8.1.2"`
  2. Update .ruby-version to 3.4.4
  3. Run `bundle update rails`
  4. Run `bundle install`
  5. Fix any deprecation warnings in tests/code
  6. Test full suite locally: `rails test`
  7. Commit: "Upgrade: Rails 8.1.2, Ruby 3.4.4"

**Token Budget:** 5k tokens

---

### Task 1.2: Multi-Region Routing Infrastructure
- **Goal:** Support AU, NZ, UK, US with geo-based routing
- **Implementation:**
  1. Create `config/regions.yml`:
     ```yaml
     regions:
       us:
         code: US
         name: United States
         currency: USD
         timezone: America/New_York
         legislation: us
       au:
         code: AU
         name: Australia
         currency: AUD
         timezone: Australia/Sydney
         legislation: au
       nz:
         code: NZ
         name: New Zealand
         currency: NZD
         timezone: Pacific/Auckland
         legislation: nz
       uk:
         code: UK
         name: United Kingdom
         currency: GBP
         timezone: Europe/London
         legislation: uk
     ```
  2. Create `RegionHelper` with methods:
     - `current_region` (from subdomain or /au, /nz, /uk paths)
     - `region_config`
     - `region_currency`
     - `region_legislation`
  3. Add region detection middleware
  4. Create region-scoped routes
  5. Test all region paths work: /, /au, /nz, /uk, /us

**Token Budget:** 8k tokens

---

### Task 1.3: Test Suite Audit
- **Goal:** Identify and fix broken tests
- **Steps:**
  1. Run full test suite: `rails test` (capture output)
  2. Categorize failures:
     - Missing models/methods
     - Fixture issues
     - CSP violations
     - Integration test failures
  3. Fix systematically (see testing process below)
  4. Target: 95% pass rate

**Testing Protocol (MANDATORY 7-STEP):**
1. Write integration test with actual HTTP requests
2. Run test locally: `rails test test/system/feature_test.rb`
3. Test actual route with curl/browser
4. Verify HTML renders (no template errors)
5. Test user interactions (forms, buttons, links)
6. Run full integration suite
7. Only then claim success

**Token Budget:** 15k tokens (break into sub-tasks if >100k needed)

---

## PHASE 2: CORE PLATFORM COMPLETION

### Task 2.1: EPM Financial Model Integration

**Reference:** `/data/Copy of FutureProofCalculator_Pavel_v10.xlsm`

**Inputs:**
- Home value (AUD/USD/GBP/NZD)
- Loan term (10, 15, 20, 25, 30 years)
- Income term (10, 15, 20, 25, 30 years)
- Mortgage type (interest-only vs. P&I)
- Borrower age(s)

**Calculation Engine:**
1. Create `CalculationEngine` service
   - Parse spreadsheet model logic
   - Implement Monte Carlo simulation (1000+ S&P 500 scenarios)
   - Calculate quarterly interest payments
   - Track reinvestment portfolio
   - Determine insurance triggers
   - Generate percentile projections (10th, 25th, 50th, 75th, 90th)

2. Quote API response should include:
   ```json
   {
     "loan_amount": 1600000,
     "monthly_income": {
       "pessimistic": 2500,
       "expected": 3200,
       "optimistic": 4100
     },
     "equity_preserved": 100,
     "insurance_coverage": true,
     "scenarios": { "percentiles": {...} }
   }
   ```

3. Create integration test:
   - Test quote generation with real home value
   - Verify calculations match spreadsheet
   - Verify all output fields present

**Token Budget:** 20k tokens

---

### Task 2.2: Multi-Region Contracts & Compliance

**Goal:** Generate region-specific contracts (template + example PDF)

**For Each Region (AU, NZ, UK, US):**

1. **Principal Mortgage Contract**
   - Lender: mortgages money to customer
   - Customer: pledges home equity
   - Region-specific legal language
   - Example: FutureProof_Mortgage_Contract_AU.docx

2. **Wholesale Funder Agreement**
   - Wholesale funder: provides capital to lender
   - Performance metrics, reporting, capital calls
   - Region-specific regulations
   - Example: FutureProof_WholesaleFunder_Agreement_AU.docx

3. **Investment Management Agreement**
   - Investment manager (e.g., BlackRock): manages portfolio
   - Fee schedule, performance reporting, rebalancing rules
   - Region-specific compliance
   - Example: FutureProof_InvestmentManagement_AU.docx

4. **Customer Terms & Conditions**
   - Loan terms, fees, early repayment, prepayment penalties
   - Region-specific consumer protections
   - Example: FutureProof_Terms_AU.docx

5. **Privacy Policy**
   - Data handling, retention, user rights
   - GDPR (UK), Privacy Act (AU), equivalent (NZ/US)
   - Example: privacy_policy_au.html.erb

6. **Broker/Referral Partner Agreement**
   - Commission structure, referral terms, compliance obligations
   - Region-specific requirements
   - Example: FutureProof_ReferralAgreement_AU.docx

**Implementation:**
1. Create `/app/views/legal/` directory
2. Create ERB templates (one per region)
3. Create controller to serve PDFs (with regional branding)
4. Link from footer + settings page
5. Store PDF copies in `/public/documents/`

**Example File Structure:**
```
app/views/legal/
  contracts/
    mortgage_contract_au.html.erb
    mortgage_contract_uk.html.erb
    mortgage_contract_nz.html.erb
    mortgage_contract_us.html.erb
  agreements/
    wholesale_funder_au.html.erb
    investment_management_au.html.erb
    referral_partner_au.html.erb
  terms/
    terms_au.html.erb
    terms_uk.html.erb
    privacy_policy_au.html.erb
```

**Token Budget:** 25k tokens (contracts are verbose; may need 2 sub-tasks)

---

### Task 2.3: Customer AI Chat System

**Goal:** Chat interface with region-appropriate AI agents

**Features:**
1. **Chat UI Component**
   - Floating chat widget (bottom-right)
   - Accessible on all customer-facing pages
   - Mobile-responsive
   - History sidebar (saved chats)
   - Theme-aware (dark mode compatible)

2. **Agent Routing**
   - **Onboarding Agent** (all users) — helps with quote, application process
   - **Loan Specialist Agent** (active customers) — investment questions, performance
   - **Legal Agent** (all) — contracts, terms, eligibility
   - **Technical Support Agent** (all) — platform issues, navigation
   - Auto-route based on context (page, user state, query)

3. **Regional Awareness**
   - Chat responds in region's legislation context
   - Links to region-specific contracts
   - Uses region's currency/terminology
   - Aware of regional eligibility rules

4. **Mock Implementation** (for MVP):
   - Pre-trained responses for common questions
   - Fallback to static FAQ if query unmatched
   - Log all conversations for future training
   - No external LLM calls (yet)

5. **Database:**
   - Create `ChatConversation` model
   - Create `ChatMessage` model (user + bot)
   - Create `ChatAgent` model (define agent types)
   - Add indexing for conversation queries

**Token Budget:** 18k tokens

---

### Task 2.4: Admin Agent Performance Dashboard (Real-Time Mockups)

**Goal:** Live-updating dashboard showing agents "solving issues"

**Components:**
1. **Agent Supervision Grid**
   - List of agents (AI + human)
   - Current status: Idle, Processing, On Break
   - Tasks completed (today, week, month)
   - Average resolution time
   - Customer satisfaction score

2. **Live Activity Stream**
   - Real-time mock updates (e.g., "Agent Sarah completed application review")
   - Timestamps
   - Icons for task types
   - Auto-refresh every 5-10 seconds
   - Sound notification (optional)

3. **Performance Metrics**
   - Total tasks processed (day/week/month)
   - Average time per task
   - Quality score (mock: 95-99%)
   - Customer satisfaction (NPS mock: 40-60)
   - Escalation rate

4. **Mock Data Generation**
   - Seeded agents + mock task queue
   - Simulate task completion (mark complete every 2-5 min)
   - Vary metrics slightly to look realistic
   - Pre-populate with 50+ completed tasks

5. **Implementation:**
   - Create `AgentPerformance` model + seed data
   - Create `AgentTask` model (completed tasks)
   - Create Stimulus controller for auto-refresh
   - Create dashboard view with cards + grid
   - Use CSS for real-time status indicators (color changes)

**Token Budget:** 12k tokens

---

## PHASE 3: UX & MOBILE OPTIMIZATION

### Task 3.1: Mobile-First Responsive Design

**Goal:** All pages render correctly on mobile (375px+), tablet (768px+), desktop

**Approach:**
1. **Audit existing pages** for mobile issues
2. **Create mobile CSS** in `/app/assets/stylesheets/mobile.css`
3. **Test breakpoints:**
   - 375px (iPhone SE)
   - 768px (iPad)
   - 1024px (iPad Pro)
   - 1440px (desktop)

4. **Key pages to optimize:**
   - Homepage + hero section
   - Quote calculator
   - Application form (multi-step)
   - Customer dashboard
   - Admin dashboard (sidebar collapse)
   - Email templates (mobile preview)

5. **Guidelines:**
   - Touch targets: 48px+ (not 44px)
   - Font sizes: 16px minimum on mobile
   - Spacing: Generous (16px min on mobile)
   - Forms: Single column on mobile, multi-column on desktop
   - Navigation: Hamburger menu on mobile

6. **Test on real devices** or browser dev tools (mobile emulation)

**Token Budget:** 10k tokens

---

### Task 3.2: Modern Apple HIG Design System Implementation

**Goal:** Consistent, elegant UI across platform

**Implement:**
1. **Typography:**
   - Primary: SF Pro, -apple-system, BlinkMacSystemFont, Segoe UI
   - Sizes: 32px (H1), 24px (H2), 20px (H3), 16px (body), 14px (caption)
   - Line height: 1.5 (body), 1.4 (headings)
   - Color: #000 (dark mode: #fff)

2. **Color Palette:**
   - Primary: Futureproof brand (teal/blue—choose one)
   - Accent: Orange/green (secondary action)
   - Status: Green (success), Red (error), Yellow (warning), Blue (info)
   - Background: #F5F5F7 (light mode), #1D1D1D (dark mode)
   - Text: #000 (light), #FFF (dark)

3. **Components:**
   - Buttons: 12px radius, 12px padding (h), 8px padding (v)
   - Cards: 12px radius, subtle shadow (0 2px 10px rgba(0,0,0,0.1))
   - Inputs: 8px radius, 12px padding, light border
   - Alerts: Card-based, icon + text + close button
   - Badges: 4px radius, padding 4px 8px, small font

4. **Animation:**
   - Transitions: 300ms cubic-bezier(0.4, 0, 0.2, 1)
   - Opacity, scale, position (not jarring)
   - No infinite loops (except loading spinners)

5. **Spacing:**
   - Use 8px grid: 8, 16, 24, 32, 40, 48px
   - Margins: 16px (mobile), 24px (tablet), 32px (desktop)
   - Padding: 12px (compact), 16px (standard), 24px (spacious)

6. **Update CSS file:**
   - Create `/app/assets/stylesheets/design_system.css`
   - Define all variables (colors, spacing, typography)
   - Create component classes
   - Document in `/DESIGN_SYSTEM.md`

**Token Budget:** 15k tokens

---

### Task 3.3: Accessibility Audit & Fixes

**Goal:** WCAG 2.1 Level AA compliance

**Check:**
1. **Color Contrast:** 4.5:1 (text), 3:1 (UI components)
2. **Keyboard Navigation:** Tab through all pages, no traps
3. **Screen Reader:** Use NVDA/JAWS to test key flows
4. **Semantic HTML:** `<button>`, `<label>`, `<header>`, `<main>`, `<nav>`
5. **ARIA Labels:** `aria-label`, `aria-describedby`, `role="alert"` where needed
6. **Focus Indicators:** Visible (not hidden)
7. **Alt Text:** All images have descriptive alt text

**Tools:**
- axe DevTools (Chrome extension)
- WAVE (accessibility.webaim.org)
- Lighthouse (Chrome DevTools)

**Fix critical issues; document remainder**

**Token Budget:** 8k tokens

---

## PHASE 4: TESTING & QUALITY ASSURANCE

### Task 4.1: Integration Test Suite Completion

**Target:** 80%+ coverage, all critical paths tested

**Priority Tests (write in this order):**

1. **Customer Quote → Application → Approval Flow**
   - User visits homepage
   - Uses calculator (home value, income)
   - Clicks "Apply Now"
   - Creates account
   - Completes application (personal, property, documents)
   - Submits
   - Receives approval email
   - Views contract
   - Signs document
   - Becomes active customer

2. **Lender Dashboard → Application Review → Contract Generation**
   - Lender logs in
   - Views pending applications
   - Reviews application details
   - Approves/rejects
   - Generates contract
   - Sends to customer

3. **Wholesale Funder → Capital Funding → Lender Management**
   - Funder logs in
   - Approves lender funding request
   - Allocates capital
   - Views funder dashboard
   - Monitors performance

4. **Admin Workflow & Email System**
   - Create email workflow (trigger → condition → email action)
   - Test workflow execution
   - Verify email sent to correct user
   - Test all trigger types

5. **Multi-Region Compliance**
   - Test AU site displays AU contracts
   - Test UK site displays UK terms
   - Test US site displays US privacy policy
   - Verify regional legal text in contracts

**Testing Framework:**
- Use Capybara + Selenium for system tests
- Create `test/system/` tests
- Each test: 1 user journey, 1 happy path
- Run: `rails test:system`

**Token Budget:** 25k tokens (this is substantial)

---

### Task 4.2: Unit & Service Tests

**Coverage Targets:**
- All models: >80%
- All services: >85%
- All controllers: >75%

**Quick Audit:**
```bash
rails test
# Count failures
# Categorize by type
```

**Fix systematically:**
1. Model tests (fastest to fix)
2. Service tests
3. Controller tests
4. Integration tests (most time)

**Don't aim for 100%** — focus on business-critical logic.

**Token Budget:** 12k tokens

---

### Task 4.3: Production Readiness Checklist

Before claiming "ready to demo," verify:

- [ ] All tests passing (>80% coverage)
- [ ] No CSP violations (run `bin/rails csp:report`)
- [ ] No N+1 queries in key pages (use Bullet gem)
- [ ] Mobile renders correctly (375px-1440px)
- [ ] All legal pages present (AU, NZ, UK, US)
- [ ] Email templates generated (6 per region)
- [ ] Admin dashboard mockups working
- [ ] Chat system functional
- [ ] Errors handled gracefully (no 500 errors)
- [ ] Performance: page load <3s (desktop), <5s (mobile)
- [ ] Security headers present (CSP, X-Frame-Options, etc.)
- [ ] Database backups working
- [ ] Deployment checklist documented

**Token Budget:** 5k tokens

---

## PHASE 5: DOCUMENTATION & DEMO PREP

### Task 5.1: System Architecture & Capabilities Document

**Output:** `/CAPABILITIES.md` (10-15 pages)

**Sections:**
1. **Executive Summary** — What FutureProof does, key differentiators
2. **Product Architecture** — Diagram: Customer → Lender → Funder flow
3. **Technology Stack** — Rails 8, PostgreSQL, Stimulus, custom CSS
4. **Security & Compliance**
   - Data encryption (AES-256 at rest, TLS in transit)
   - Authentication (SSO, MFA)
   - Authorization (RBAC)
   - Audit logging
   - GDPR/Privacy Act compliance status
   - SOC2 Type II roadmap
5. **Multi-Region Support** — AU, NZ, UK, US legal frameworks
6. **Integration Points** (mocked for MVP)
   - CoreLogic (property valuation)
   - Investment Manager API (fund management)
   - Payment Gateway (income disbursement)
   - DocuSign (e-signatures)
   - Email Service (SendGrid)
7. **Agent-Driven Operations**
   - Customer service agents
   - Onboarding agents
   - Compliance/legal agents
   - Reporting agents
   - Mock performance dashboard
8. **Financial Model** — Monte Carlo simulation, percentile calculations
9. **User Journeys** — Screenshots/flows for each stakeholder type
10. **Future Roadmap** — Post-MVP features (mobile app, blockchain, etc.)

**Include:**
- Architecture diagram (Mermaid or visual)
- Security audit summary
- Performance benchmarks
- Team & roles required for launch
- Cost estimates

**Token Budget:** 10k tokens

---

### Task 5.2: VC Pitch Deck (Optional, but recommended)

**Output:** `/PITCH_DECK.pdf` (15-20 slides)

**Slides:**
1. Title: "FutureProof EPM Platform"
2. Problem: "Retirees deplete home equity; reverse mortgages compound debt"
3. Solution: "Preserve equity, get tax-free income, preserve inheritance"
4. Market: "$2T+ untapped retirement liquidity (AU + UK + US)"
5. Product: Core features (quote, app, dashboard)
6. Technology: Agent-driven, scalable, multi-region
7. Business Model: Fee-based + revenue share
8. Go-To-Market: B2B2C (lenders as distribution)
9. Team (mock bios if real team unavailable)
10. Financials (revenue projections)
11. Funding Ask: $X for MVP launch
12. Roadmap: 18-month vision
13. Competitive Advantage: Technology, speed, user experience
14. Traction (or "ready for beta")
15. Close: "Join us in transforming retirement"

**Tools:** Google Slides, Keynote, or Figma

**Token Budget:** 8k tokens (optional)

---

### Task 5.3: Deployment & Launch Checklist

**Output:** `/DEPLOYMENT_CHECKLIST.md`

**Pre-Launch Verification:**
```markdown
## Environment Setup
- [ ] Production database configured
- [ ] Redis/cache configured
- [ ] Email service credentials set
- [ ] S3/file storage configured
- [ ] CDN/DNS configured
- [ ] SSL certificate installed
- [ ] Monitoring/logging set up (Sentry, LogRocket, etc.)

## Data Migration
- [ ] Production data imported
- [ ] Customer records seeded (if needed)
- [ ] Lender accounts created
- [ ] Regional templates activated

## Testing
- [ ] All tests passing
- [ ] Smoke tests run (manual checks of critical flows)
- [ ] Mobile device testing completed
- [ ] Performance testing under load
- [ ] Security scan completed

## Documentation
- [ ] User guides published
- [ ] Admin documentation complete
- [ ] API docs generated (if exposing APIs)
- [ ] Runbooks for common issues

## Launch Day
- [ ] Team on standby
- [ ] Monitoring dashboards active
- [ ] Support channels ready
- [ ] Marketing communication prepared
- [ ] Database backups confirmed
- [ ] Rollback plan documented

## Post-Launch (24h)
- [ ] Monitor error logs
- [ ] Check performance metrics
- [ ] Gather user feedback
- [ ] Fix critical bugs immediately
```

**Token Budget:** 3k tokens

---

## PHASE 6: CLEANUP & OPTIMIZATION

### Task 6.1: Code Quality & Standards

**Checklist:**
1. Run RuboCop: `bundle exec rubocop` — fix style issues
2. Run Brakeman: `bundle exec brakeman` — security audit
3. Run Rails Best Practices: `rails_best_practices`
4. Commit message standards: "Type: Description" (Conventional Commits)
5. Remove dead code (old test helpers, unused methods)
6. Add missing inline documentation for complex logic

**Token Budget:** 5k tokens

---

### Task 6.2: Performance Optimization

**Quick Wins:**
1. Add database indexes on frequently queried columns
2. Cache repeated calculations (e.g., quote calculator)
3. Lazy-load images and heavy components
4. Minimize CSS/JS bundle sizes
5. Set up CDN for static assets
6. Enable gzip compression on responses

**Measure:**
```bash
rails perf:check  # If available in Rails 8
# OR
time curl https://localhost:3001 > /dev/null
```

**Token Budget:** 8k tokens

---

## PHASE SEQUENCING & TOKEN BUDGETS

**Recommended Order** (minimize back-and-forth):

| Phase | Task | Tokens | Dependencies |
|-------|------|--------|--------------|
| 0 | Setup & Rules | 0 | None |
| 1.1 | Rails/Ruby Upgrade | 5k | None |
| 1.2 | Multi-Region Routing | 8k | 1.1 |
| 1.3 | Test Audit | 15k | 1.1 |
| 2.1 | EPM Financial Model | 20k | 1.1 |
| 2.2 | Contracts & Compliance | 25k | 1.2 |
| 2.3 | Customer AI Chat | 18k | 1.2, 2.1 |
| 2.4 | Agent Performance Dashboard | 12k | 2.1 |
| 3.1 | Mobile Responsive | 10k | 1.1 |
| 3.2 | Design System | 15k | 3.1 |
| 3.3 | Accessibility | 8k | 3.2 |
| 4.1 | Integration Tests | 25k | All Phase 2, 3 |
| 4.2 | Unit Tests | 12k | 4.1 |
| 4.3 | Readiness Checklist | 5k | 4.1, 4.2 |
| 5.1 | Capabilities Doc | 10k | 4.3 |
| 5.2 | Pitch Deck (optional) | 8k | 5.1 |
| 5.3 | Deployment Checklist | 3k | 5.1 |
| 6.1 | Code Quality | 5k | All |
| 6.2 | Performance | 8k | All |
| **TOTAL** | | **223k tokens** | Sequential |

**Budget Recommendation:** 200k tokens (assume some efficiency gains)

---

## CLAUDE.MD - AI & TECHNICAL REFERENCE

This section is for **quick lookups during development**. Include in project as `/CLAUDE.md`.

### 🔴 CRITICAL RULES (MEMORIZE)

**Data Safety:**
- NEVER: `rails db:drop`, delete records, truncate tables
- ALWAYS: Ask permission before any data operation
- ZERO TOLERANCE: Data loss = project failure

**Deployment:**
- ALWAYS verify: `fly auth whoami` + `fly status` before deploying
- Wrong login = overwrites wrong app
- Check mandatory before `fly deploy`

**CSP Compliance:**
- NO inline styles, scripts, event handlers
- All CSS external (`/app/assets/stylesheets/`)
- All JS external (`/app/javascript/` Stimulus controllers)
- Run `bin/rails csp:report` before every commit

**CSS Rules:**
- 100% custom CSS only
- Check `/app/assets/stylesheets/admin.css` for available classes
- NO Tailwind, Bootstrap, or external frameworks
- Use: `admin-form-*`, `admin-table`, `status-badge`

**Testing Protocol (7-Step Mandatory):**
1. Write integration test
2. Run test locally
3. Test actual URL (curl/browser)
4. Verify HTML renders
5. Test user interactions
6. Run full suite
7. Only then claim success

### 🏗️ PROJECT CONTEXT

**Rails Version:** 8.1.x, Ruby 3.4.4  
**Database:** PostgreSQL  
**Frontend:** Stimulus (UI only), custom CSS  
**Deployment:** Fly.io (app: futureproof-epm-platform)  
**Regions:** AU, NZ, UK, US (geo-routed)

**Key Models:**
- `User`, `Application`, `Contract`, `Mortgage`
- `Lender`, `WholesaleFunder`, `FunderPool`
- `EmailTemplate`, `EmailWorkflow`, `Trigger`
- `AiAgent`, `AgentTask`, `AgentPerformance`
- `ChatConversation`, `ChatMessage`

**Key Controllers:**
- `/admin/applications` — application management
- `/admin/dashboard` — oversight + agent performance
- `/customers/dashboard` — borrower portal
- `/lenders/dashboard` — lender portal
- `/admin/email_workflows` — workflow builder

**Key Services:**
- `CalculationEngine` — quote + EPM financial model
- `EmailHeaderFooterService` — regional email templates
- `AiAgentRouter` — route chats to correct agent
- `AgentPerformanceTracker` — mock agent metrics

### 📋 COMMON COMMANDS

```bash
# Development
rails server -p 3001

# Testing (7-step process)
rails test                          # All tests
rails test test/system/flows_test.rb  # Single test file
rails test:system                   # System tests only

# Security & Compliance
bin/rails csp:report                # Check CSP violations
bundle exec brakeman                # Security audit
bundle exec rubocop                 # Style guide

# Database
rails db:create
rails db:migrate
rails db:seed                       # (ask permission first!)
rails db:rollback                   # (ask permission first!)

# Deployment (MANDATORY CHECKS FIRST)
fly auth whoami                     # Who am I?
fly status                          # Which app?
fly deploy --remote-only            # Only after above 2

# Git workflow
git status                          # Current state
git log --oneline -20               # Recent commits
git commit -m "Type: Description"   # Conventional commits
git push origin main                # To main branch
```

### 🧮 FINANCIAL MODEL (EPM)

**Key Variables:**
- `home_value` — AUD/USD/GBP/NZD
- `ltv` — 80% max
- `loan_amount` — ltv * home_value
- `loan_term` — 10, 15, 20, 25, 30 years
- `income_term` — 10, 15, 20, 25, 30 years
- `income_rate` — 1.5-2% annual (varies by scenario)

**Calculation:**
1. Loan amount: `home_value * 0.80`
2. Monthly income (expected): `loan_amount * income_rate / 12`
3. Investment portfolio: 70% of loan amount, S&P 500 ETF
4. Annuity portion: 30% of loan amount, treasury ladder
5. Quarterly interest paid from investment returns
6. Insurance covers shortfalls

**Outputs:**
- Monthly income (pessimistic, expected, optimistic)
- Equity preserved: 100%
- Scenarios: 1000+ Monte Carlo runs
- Percentiles: 10th, 25th, 50th, 75th, 90th

### 🌍 MULTI-REGION SETUP

**Regions Config:** `/config/regions.yml`

**Region Routes:**
- `www.futureproof.com` or `/` → US
- `www.futureproof.com/au` or `au.futureproof.com` → Australia
- `www.futureproof.com/nz` or `nz.futureproof.com` → New Zealand
- `www.futureproof.com/uk` or `uk.futureproof.com` → United Kingdom

**Region-Specific Content:**
- Legal: Contracts, terms, privacy policies (region-specific ERB templates)
- Currency: Display in region's currency
- Timezone: Use region's timezone
- Legislation: Apply region-specific rules

### 🤖 AGENT SYSTEM

**Agent Types:**
1. **Onboarding Agent** — Helps new customers through quote → application
2. **Loan Specialist Agent** — Answers questions about investment, payments
3. **Legal Agent** — Explains contracts, eligibility, compliance
4. **Technical Support Agent** — Platform issues, navigation
5. **Operations Agent** (admin) — Workflow creation, compliance, reporting

**Chat Context:**
- Agent types defined in database (`AiAgent` model)
- Chat router (`AiAgentRouter` service) selects appropriate agent
- Mock responses from pre-trained dataset
- Log conversations for future LLM training

**Performance Dashboard:**
- Real-time updates (Stimulus controller with auto-refresh)
- Mock agent tasks completing every 2-5 minutes
- Metrics: completed tasks, avg resolution time, satisfaction

### ✅ TESTING CHECKLIST

**Before claiming "done":**
- [ ] Integration test written (real HTTP requests)
- [ ] Test runs locally: `rails test test/system/...`
- [ ] Actual URL tested (curl or browser)
- [ ] HTML renders (no template errors)
- [ ] User interactions work (buttons, forms, links)
- [ ] Full suite passes: `rails test`
- [ ] CSP compliance: `bin/rails csp:report`

**If any step fails, fix before moving on.**

---

## KNOWN GOTCHAS & LESSONS LEARNED

### Token Management
- **Break tasks into chunks <15k tokens** — prevents agent timeout
- **Sub-task dependencies clearly marked** — prevents parallel conflicts
- **Always check `session_status` before large work**
- **If approaching 100k context, start fresh session**

### Rails 8 Specifics
- Solid Queue replaces Sidekiq (built-in)
- Solid Cache replaces Redis (built-in)
- Prop shaft replaces Webpacker (simpler asset pipeline)
- Ensure Gemfile updated to latest versions

### CSP Violations (Common Mistakes)
- ❌ Adding `style="color: red"` inline — use CSS class instead
- ❌ `onclick="method()"` handlers — use Stimulus `data-action`
- ❌ Inline `<script>` tags in views — create Stimulus controller
- ❌ Using framework classes (Tailwind/Bootstrap) — use custom classes

### Testing Gotchas
- ❌ Unit test passing ≠ integration test passing
- ❌ Template exists ≠ HTML renders (vars might be nil)
- ❌ Form submits ≠ validation passes
- Always test full flow, not just one step

### Multi-Region Gotchas
- ❌ Hardcoded "Australia" string — use `region_config.name`
- ❌ USD currency in AU region — use `region_config.currency`
- ❌ Ignoring timezone differences — time calculations will fail
- Always use region helper methods

---

## SUCCESS CRITERIA (FINAL CHECKLIST)

**Before claiming "VC-Ready":**

- ✅ All features implemented (no placeholders)
- ✅ Tests passing (>80% coverage, all integration paths)
- ✅ Mobile responsive (375px - 1440px)
- ✅ Modern UX (Apple HIG standards)
- ✅ Multi-region support (AU, NZ, UK, US with local contracts)
- ✅ AI Chat working (agent routing, region-aware)
- ✅ Admin agent dashboard (real-time mockups)
- ✅ EPM calculator (spreadsheet model integrated)
- ✅ CSP compliance (no violations)
- ✅ Security documentation (encryption, auth, compliance)
- ✅ Example contracts (6 templates per region)
- ✅ Performance: <3s page load (desktop), <5s (mobile)
- ✅ Deployment checklist verified
- ✅ Capabilities document (10+ pages)
- ✅ Ready to launch (external APIs pending)

**If all checked: Cleared for VC demo.**

---

## CONTACT & ESCALATION

**Blockers?**
- Data safety questions → Ask before acting
- Unclear requirements → Reference BUSINESS_REQUIREMENTS.md
- Token budget exceeded → Start fresh session, reference this document
- Security concerns → Check CSP_COMPLIANCE.md and CRITICAL RULES above

**Questions about EPM model?** → See spreadsheet at `/data/Copy of FutureProofCalculator_Pavel_v10.xlsm`

**Questions about Rails?** → Check CLAUDE.md common commands and services

---

## VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-04 | Initial comprehensive refactoring prompt |

---

**Last Updated:** 2026-03-04 18:50 GMT+11  
**Status:** Ready for execution  
**Estimated Total Tokens:** 200-220k (sequential, minimal waste)
