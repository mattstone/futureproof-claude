# FutureProof Current State Audit

**Date:** 2026-03-07 00:10 GMT+11  
**Purpose:** Determine what's ACTUALLY built vs. what's ASPIRATIONAL  
**Status:** IN PROGRESS - Comprehensive assessment

---

## Database & Models (What EXISTS)

### Data Present
- **51 Users** (test accounts)
- **128 Applications** (in various workflow stages)
- **25 Contracts** (mortgage contracts)
- **4 Mortgages** (active loans)
- **5 Lenders** (AU, US, NZ, UK)
- **5 Wholesale Funders** (ecosystem)

### Application Workflow States (REAL)
```
created → user_details → property_details → income_and_loan_options → submitted → processing → accepted/rejected
```

States distribution:
- created: 56
- user_details: 10
- property_details: 12
- income_and_loan_options: 10
- submitted: 16
- processing: 10
- accepted: 8
- rejected: 6

**Meaning:** Basic application workflow IS implemented (not mocked).

### Models That Exist (56 total)
✅ **Core Domain Models:**
- User, Application, Contract, Mortgage
- Lender, WholesaleFunder, FunderPool
- EmailTemplate, EmailWorkflow
- ChatAgent, ChatConversation, ChatMessage
- AgentTask, AgentPerformance, AgentAction
- ApplicationVersion (via PaperTrail)

✅ **But Schema Doesn't Match EPM Structure:**
- `Lender` has: name, address, postcode, country, contact_email
- `Lender` missing: region, abn, max_loan_amount, min_customer_age, max_customer_age
- `Application` missing: lender_id (FK to Lender)
- `Application` missing: approved_loan_amount, approved_interest_rate, approved_term_years
- `Contract` ≠ `MortgageContract` (different model)

---

## What's ACTUALLY Built (Real Code, Not Mocked)

### ✅ Services Layer (REAL)

**CalculationEngine** (19KB)
- Multi-region support (AU, US, NZ, UK)
- Scenario generation (pessimistic/expected/optimistic)
- CPI escalation logic (up to 4% annual cap)
- NNEG analysis (No Negative Equity Guarantee)
- FX sensitivity for non-USD regions
- Estate impact projections
- **Status:** 85% complete, working with seed data

**AiAgentRouter** (8KB)
- Routes messages to 5 agent types (Onboarding, Loan Specialist, Legal, Technical, Operations)
- Region-aware responses
- **Status:** Mock responses only (not real AI integration)

**Agent Services** (AgentDecisionService, AgentLifecycleService)
- Agent task management
- Performance tracking
- Workflow supervision
- **Status:** Partially integrated

### ✅ Views & UI (Real Templates)

**Legal Documents**
- ✅ AU mortgage contract with NNEG clause
- ✅ US, NZ, UK mortgage contracts (region-specific)
- ✅ Privacy policies (4 regions)
- ✅ Terms of service (4 regions)
- ✅ Referral partner agreements
- ✅ Wholesale funder agreements
- **Status:** Templates exist, can be served

**Design System**
- ✅ design_system.css (12KB) - Apple HIG design system
- ✅ mobile.css (8KB) - Responsive CSS (375px-1440px)
- **Status:** CSS files exist, but unclear if fully integrated in all views

**Dashboard Pages**
- ✅ Agent performance dashboard (real-time mockups)
- ✅ Business profitability dashboard
- **Status:** Views exist, data may be mocked

### ✅ Multi-Region Routing (PARTIAL)

**Routes** (`config/routes.rb`)
```ruby
scope "/:region", constraints: { region: /au|nz|uk/ } do
  get "privacy-policy", to: "pages#privacy_policy"
  get "terms-of-use", to: "pages#terms_of_use"
  get "/", to: "pages#get_started"
end
```

**Region Detection** (`pages_controller.rb`)
- Detects region from CloudFlare headers
- Detects region from Fly.io headers
- Falls back to Accept-Language header
- Defaults to US
- **Status:** Works for landing pages, not full application

**Status:** ⚠️ **Partial** - Legal documents support multi-region, but application workflow doesn't distinguish by region.

### ✅ Quote/Calculator API

**Endpoint:** `/api/quotes/regional`
- Calls CalculationEngine
- Returns quote with region-specific rates
- **Status:** Exists, may not be integrated in UI

---

## What's INCOMPLETE (Half-Finished)

### ❌ Application Approval Workflow
**Missing:**
- Lender review screen (to view pending applications)
- Approval action (set approved_loan_amount, approved_interest_rate)
- Rejection workflow (with documented reason)
- **Database columns don't exist** (approved_loan_amount, approved_interest_rate)

**Status:** Cannot be fully tested without schema changes.

### ❌ Contract Generation from Application
**Missing:**
- Trigger to generate contract on approval
- Contract template selection by region
- Contract HTML rendering from template
- **Relationship:** Application → Contract (not clear if exists)

**Status:** Services exist but integration unclear.

### ❌ Interest Holiday Logic
**Missing:**
- Fund performance monitoring trigger
- Holiday entry/exit calculation (90% / 145.8% thresholds)
- Accrual of margin to principal
- Distribution Agent workflow

**Status:** Designed but not implemented.

### ❌ Monthly Distribution Pipeline
**Missing:**
- Monthly aggregation of fund returns
- Margin deduction logic
- Payment processing (ACH/EFT)
- Distribution reporting

**Status:** Not started.

### ❌ Full Multi-Region Application
**Missing:**
- Application form respects region-specific requirements
- Region-specific templates for contracts
- Region-specific compliance checks
- Region-specific agent responses

**Status:** Framework exists, integration incomplete.

---

## What's MISSING Entirely (Not Started)

### ❌ Lender Portal / Admin Features
**Missing:**
- Lender dashboard (view pending applications)
- Application review/approval interface
- Contract issuance workflow
- Portfolio monitoring

**Status:** 0% (admin section exists but EPM-specific features missing)

### ❌ Funder Portal
**Missing:**
- Wholesale funder dashboard
- Fund performance visualization
- Pool allocation management
- Distribution reporting

**Status:** 0%

### ❌ Broker Integration
**Missing:**
- Broker API (submit applications on behalf of customers)
- Commission tracking
- Partner management portal

**Status:** 0%

### ❌ Real AI Integration
**Missing:**
- Claude/GPT integration (AiAgentRouter returns mocks only)
- Token counting / cost tracking
- Real conversation history

**Status:** Scaffold only, no real AI.

### ❌ Compliance Features
**Missing:**
- KYC/AML verification
- Fraud detection
- Audit trail dashboard
- Regulatory reporting

**Status:** 0%

### ❌ Settlement & Closing
**Missing:**
- Document collection workflow
- Title verification
- Title transfer process
- Funding trigger

**Status:** 0%

---

## Test Coverage Assessment

### Tests That Pass (474 total)
✅ Mostly controller tests (HTTP routing)
✅ Model relationship tests (simple associations)
✅ Email template tests
✅ Admin UI tests

### Tests That Would Fail If Run (Never Written)
❌ End-to-end quote → application → approval → contract flow
❌ Multi-region routing for full application
❌ Contract generation from application
❌ Lender approval workflow
❌ Interest holiday triggers
❌ Distribution pipeline

---

## Production Readiness Assessment

### Can Launch Today With Limitations
✅ **YES** if:
- Customers can sign up and fill out application
- Application data persists
- Admin can view applications
- Legal documents serve correctly

❌ **NO** if:
- Lenders need to review and approve applications
- Contracts need to be auto-generated
- Monthly distributions need to process
- Multi-region compliance matters
- Real AI chat is needed

---

## Real Blockers (What MUST Be Done Before Launch)

### Critical Path Items

| Item | Status | Impact | Effort |
|------|--------|--------|--------|
| **Lender Approval Workflow** | ❌ Missing | Can't close loans | HIGH |
| **Contract Auto-Generation** | ⚠️ Partial | Can't document agreements | HIGH |
| **Payment Processing** | ❌ Missing | Can't fund customers | CRITICAL |
| **Multi-Region Full Integration** | ⚠️ Partial | Compliance risk | MEDIUM |
| **Compliance (KYC/AML)** | ❌ Missing | Regulatory risk | MEDIUM |

---

## Summary

### What Works
✅ Users can sign up
✅ Users can fill application
✅ Admin can see applications
✅ Legal documents exist
✅ Calculation engine works
✅ Chat agent router exists (with mocks)
✅ Test suite passes (474 tests)

### What's Half-Built
⚠️ Multi-region support (framework there, not integrated everywhere)
⚠️ AI integration (scaffold only, no real Claude)
⚠️ Design system (CSS exists, unclear if used consistently)
⚠️ Contract management (templates exist, generation unclear)

### What's Missing Entirely
❌ Lender/funder/broker portals
❌ Approval workflows
❌ Payment processing
❌ Compliance & KYC/AML
❌ Settlement & closing
❌ Real AI integration
❌ Interest holiday logic
❌ Monthly distributions

---

## Honest Status

**You have a 40% complete platform that:**
- ✅ Can accept customer applications
- ❌ Cannot process them end-to-end
- ❌ Cannot fund them
- ❌ Cannot distribute monthly payments

**The VC pitch document assumes 100% completeness. It's not accurate.**

**Before launching, you need:**
1. Lender approval workflow (days 1-2)
2. Contract generation (days 3-4)
3. Payment processing (days 5-7)
4. Compliance checks (days 8-10)

---

## Next Steps

I will:
1. **Complete** any actually-in-progress items from Sessions 1-2
2. **Stop** creating aspirational test files
3. **Build** the critical missing pieces: Lender workflow, contracts, payments
4. **Document** accurately what's done vs. what needs doing

No more half-finished features.

