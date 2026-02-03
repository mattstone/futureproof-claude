# Futureproof Platform - Business Requirements Document

**Document Version:** 1.0 DRAFT
**Date:** December 2025
**Status:** FOR BUSINESS REVIEW

---

## Executive Summary

Futureproof is a technology platform enabling customers to obtain quotes, apply for, and manage **Equity Preservation Mortgages (EPM)** - an innovative financial product that allows homeowner retirees to convert home equity into tax-free retirement income while preserving 100% of their home equity for intergenerational wealth transfer.

This document captures the complete business requirements for stakeholder review before development begins.

---

## 1. PRODUCT DEFINITION: Equity Preservation Mortgage (EPM)

### 1.1 What is an EPM?

An Equity Preservation Mortgage is a mortgage product where:

1. **A Lender** takes a mortgage over a customer's property (up to 80% LTV)
2. **An Investment Manager** receives the mortgage funds and invests them (primarily S&P 500 ETFs)
3. **The Customer** receives agreed monthly income (paid from investment returns)
4. **Futureproof** manages the entire ecosystem via its technology platform
5. **Insurance/Pool Coverage** covers any shortfall between investment returns and customer payments

### 1.2 Key Product Differentiators

| Feature | Traditional Reverse Mortgage | EPM |
|---------|------------------------------|-----|
| Interest | Compound (debt grows) | Simple (no compounding) |
| Equity | Depletes over time | 100% preserved |
| Age Restriction | Usually 62+ | No age restrictions |
| LTV Restrictions | Age-dependent | Up to 80% any age |
| Serviceability Risk | On borrower | Removed (interest paid by platform) |
| Wealth Transfer | Debt reduces inheritance | Full home value to heirs |

### 1.3 Financial Structure

```
Customer's Home ($2M value)
          |
    80% LTV Loan ($1.6M)
          |
    +-----+-----+
    |           |
Annuity     Reinvestment
Portion     Portion (70%)
    |           |
Monthly     Invested in
Income      S&P 500 ETFs
to Customer (via BlackRock)
```

### 1.4 Business Rules - REQUIRES CONFIRMATION

- [ ] **Maximum LTV:** 80% of home value
- [ ] **Minimum Home Value:** $500,000 (or market-specific?)
- [ ] **Maximum Home Value:** $10,000,000 (or unlimited?)
- [ ] **Loan Terms:** 10, 15, 20, 25, 30 years
- [ ] **Annuity Terms:** 10, 15, 20, 25, 30 years
- [ ] **Annual Income Rate:** 1.5%-2% of home value
- [ ] **Eligible Properties:** Primary residence AND/OR investment property?
- [ ] **Geographic Eligibility:** Australia first, then UK, then USA?
- [ ] **Borrower Age Range:** 18-85 (confirm no upper limit?)

**QUESTION FOR BUSINESS:** Are there any additional eligibility criteria (credit score, existing mortgage limits, property type restrictions)?

---

## 2. STAKEHOLDER DEFINITIONS & PORTAL REQUIREMENTS

### 2.1 Stakeholder Ecosystem

```
                    WHOLESALE FUNDERS
                    (Capital Providers)
                           |
                    Provide capital to
                           |
                       LENDERS
                    (Customer facing)
                           |
        +------------------+------------------+
        |                  |                  |
   Direct Sales     Mortgage Brokers    Referral Partners
                         |              (Accountants, Lawyers,
                    Introduce           Financial Planners)
                         |
                     CUSTOMERS
                    (EPM Borrowers)
                         |
                    Apply via
                         |
                    FUTUREPROOF
                    (Platform)
                         |
                    Instructs
                         |
                 INVESTMENT MANAGER
                 (Receives funds,
                  manages investments,
                  remits income)
```

---

### 2.2 WHOLESALE FUNDERS Portal

**User Type:** Institutional capital providers (banks, pension funds, family offices)

**Onboarding Requirements:**
- [ ] Company registration details
- [ ] Regulatory licensing verification
- [ ] Contact person(s) and roles
- [ ] AML/KYC compliance documentation
- [ ] Capital commitment terms
- [ ] Preferred investment criteria

**Dashboard Metrics (Octalysis: Accomplishment, Ownership):**
- [ ] Total capital deployed
- [ ] Current allocation across lenders
- [ ] Return on deployed capital (XIRR, CAGR)
- [ ] Portfolio health indicators
- [ ] Loan performance by lender
- [ ] Risk exposure analysis
- [ ] Available capacity for new funding
- [ ] Historical performance charts

**Key Actions:**
- [ ] View/approve funding requests from lenders
- [ ] Set funding parameters (min/max, rates, terms)
- [ ] Download reports (monthly, quarterly, annual)
- [ ] Manage pool allocations

**QUESTION FOR BUSINESS:** What level of loan-level detail should wholesale funders see? Aggregated only or individual loan data?

---

### 2.3 LENDERS Portal

**User Type:** Financial institutions with customer relationships (banks, non-bank lenders)

**Onboarding Requirements:**
- [ ] AFSL/licensing verification
- [ ] Company registration details
- [ ] Wholesale funder assignment(s)
- [ ] Branding/white-label configuration
- [ ] Interest rate margins setup
- [ ] Legal clause library configuration
- [ ] Staff user account setup

**Dashboard Metrics (Octalysis: Accomplishment, Meaning):**
- [ ] Total loan book value
- [ ] Active applications (by status)
- [ ] Monthly origination volume
- [ ] Average loan size
- [ ] Conversion rates (quote → application → settlement)
- [ ] Customer demographics
- [ ] Geographic distribution
- [ ] Referral channel performance
- [ ] Compliance/audit status

**Key Actions:**
- [ ] Review and approve/reject applications
- [ ] Message customers
- [ ] Generate contracts
- [ ] Configure legal clauses
- [ ] Manage broker relationships
- [ ] Download compliance reports
- [ ] Set up automated email workflows

**White-Label Configuration:**
- [ ] Logo upload
- [ ] Color scheme customization
- [ ] Custom email templates
- [ ] Branded customer portal
- [ ] Custom domain (optional)

---

### 2.4 REFERRAL PARTNERS Portal (Brokers, Accountants, Lawyers, Financial Planners)

**User Type:** Professionals who introduce customers to lenders

**Onboarding Requirements:**
- [ ] Professional registration/license number
- [ ] Practice/company details
- [ ] Lender affiliation(s)
- [ ] Commission structure agreement
- [ ] Contact details

**Dashboard Metrics (Octalysis: Accomplishment, Social Influence):**
- [ ] Total referrals submitted
- [ ] Conversion rate (referral → settlement)
- [ ] Commission earned (pending, paid, total)
- [ ] Customer satisfaction ratings
- [ ] Leaderboard position (optional gamification)
- [ ] Recent activity timeline

**Key Actions:**
- [ ] Submit new customer referral
- [ ] Track referral status
- [ ] View commission statements
- [ ] Download marketing materials
- [ ] Access training resources
- [ ] Message lender account manager

**QUESTION FOR BUSINESS:** Should referral partners see customer details after handoff, or only status updates?

---

### 2.5 CUSTOMERS Portal

**User Type:** Homeowner retirees seeking EPM products

**Journey Phases:**

#### Phase 1: Quote & Discovery (Octalysis: Curiosity, Meaning)
- [ ] Interactive calculator on homepage
- [ ] Input: Home value (slider $500K-$10M)
- [ ] Input: Desired monthly income
- [ ] Input: Property location (postcode)
- [ ] Output: Estimated monthly income range
- [ ] Output: Loan amount required
- [ ] Output: Equity preservation guarantee visualization
- [ ] Clear explanation of how EPM works
- [ ] Video testimonials (social proof)
- [ ] FAQ section

#### Phase 2: Application (Octalysis: Accomplishment, Progress)
- [ ] Account creation (email verification)
- [ ] Step 1: Personal Details (name, DOB, contact)
- [ ] Step 2: Property Details (address, ownership type, current mortgage)
- [ ] Step 3: Property Valuation (CoreLogic integration)
- [ ] Step 4: Loan Preferences (term, payout duration, mortgage type)
- [ ] Step 5: Document Upload (ID, property docs)
- [ ] Step 6: Review & Submit
- [ ] Progress indicator showing completion percentage
- [ ] Save & continue later functionality
- [ ] Chat/message support integration

#### Phase 3: Processing & Approval (Octalysis: Unpredictability, Avoidance)
- [ ] Application status tracking
- [ ] Timeline visualization
- [ ] Document request handling
- [ ] Secure messaging with lender
- [ ] Approval notification
- [ ] Contract review & e-signature

#### Phase 4: Active Loan Management (Octalysis: Ownership, Empowerment)
- [ ] Dashboard showing loan details
- [ ] Monthly income payment history
- [ ] Investment performance visualization
- [ ] Equity preservation status
- [ ] Contact support
- [ ] Document archive access
- [ ] Annual statement downloads

**QUESTION FOR BUSINESS:** Should customers see investment performance details, or just their income payments?

---

### 2.6 INVESTMENT MANAGER Portal

**User Type:** Asset managers (e.g., BlackRock) managing invested funds

**Onboarding Requirements:**
- [ ] Institutional credentials
- [ ] API integration setup
- [ ] Reporting configuration
- [ ] Compliance framework alignment

**Dashboard Metrics:**
- [ ] Total assets under management
- [ ] Portfolio allocation breakdown
- [ ] Performance vs benchmark
- [ ] Cash flow (inflows/outflows)
- [ ] Pending transactions
- [ ] Rebalancing alerts

**Key Actions:**
- [ ] Receive fund transfer instructions from Futureproof
- [ ] Execute investment strategy
- [ ] Remit monthly income to Futureproof
- [ ] Generate performance reports
- [ ] Manage hedging positions

**Integration Points:**
- [ ] Receive new loan funding notifications
- [ ] API for account setup
- [ ] Automated income remittance
- [ ] Performance data feed

---

### 2.7 FUTUREPROOF Admin Portal

**User Type:** Internal staff managing the platform

**Capabilities:**
- [ ] Global dashboard (all stakeholders, all metrics)
- [ ] User management (all user types)
- [ ] Application management (view, edit, override)
- [ ] Contract management
- [ ] Email template configuration
- [ ] Workflow automation builder
- [ ] Financial reconciliation
- [ ] Audit logs
- [ ] System configuration
- [ ] Report generation
- [ ] Support ticket management

**Super Admin vs. Operations Staff Permissions:**
- [ ] Role-based access control
- [ ] Audit trail for all actions
- [ ] Two-factor authentication mandatory

---

## 3. CALCULATION ENGINE REQUIREMENTS

### 3.1 Quote Calculator (Customer-Facing)

**Inputs:**
- Home value
- Property location/postcode
- Borrower age(s)
- Desired loan term
- Desired income payout term
- Mortgage type (interest only vs. principal & interest)

**Outputs:**
- Estimated monthly income (range: pessimistic to optimistic)
- Total loan amount
- Equity preserved percentage
- Comparison to reverse mortgage (debt growth visualization)

### 3.2 Financial Model (Backend)

**Monte Carlo Simulation Engine:**
- Generate 1,000+ market scenarios
- Model S&P 500 returns (historical and projected)
- Calculate quarterly interest payments
- Track reinvestment portfolio value
- Determine insurance trigger events
- Calculate XIRR, CAGR for funders
- Output percentile-based projections (10th, 25th, 50th, 75th, 90th)

**QUESTION FOR BUSINESS:** Should customers see probabilistic outcomes (e.g., "70% chance of X income"), or just a single "expected" figure?

---

## 4. USER EXPERIENCE & DESIGN REQUIREMENTS

### 4.1 Design System: Apple Human Interface Guidelines

**Core Principles:**
- **Clarity:** Text legible, icons precise, functionality obvious
- **Deference:** Fluid motion, content-first, subtle UI
- **Depth:** Visual layers, realistic motion, intuitive hierarchy

**Typography:**
- Primary: SF Pro (or equivalent system font)
- Clear hierarchy: Large titles, body text, captions
- High contrast for accessibility

**Color Palette:**
- Primary: Futureproof brand colors
- Accent: Clear, accessible action colors
- Dark mode support (optional but recommended)

**Components:**
- Cards with subtle shadows
- Rounded corners (12-16px radius)
- Generous whitespace
- Smooth animations (300ms transitions)
- Pull-to-refresh patterns
- Haptic feedback considerations (mobile)

**Responsive Design:**
- Mobile-first approach
- Tablet optimization
- Desktop enhancement
- Consistent experience across breakpoints

### 4.2 Gamification: Octalysis Framework

**Core Drives to Implement:**

1. **Epic Meaning (Narrative):**
   - "Preserve your legacy" messaging
   - Family wealth protection story
   - Retirement security mission

2. **Accomplishment (Progress):**
   - Application progress bars
   - Milestone celebrations
   - Completion badges

3. **Empowerment (Choice):**
   - Calculator customization
   - Multiple loan configurations
   - Preference controls

4. **Ownership (Collection):**
   - Personal dashboard
   - Document library
   - Portfolio visualization

5. **Social Influence (Community):**
   - Testimonials
   - Referral programs
   - Broker leaderboards

6. **Scarcity (Urgency):**
   - Limited-time rates (if applicable)
   - Application deadlines (soft)

7. **Unpredictability (Curiosity):**
   - Interactive calculator reveals
   - Progressive disclosure

8. **Avoidance (Loss Prevention):**
   - Equity depletion warnings (vs. reverse mortgage)
   - Save progress prompts

---

## 5. TECHNICAL REQUIREMENTS

### 5.1 Platform Architecture

- **Framework:** Ruby on Rails 8.x
- **Database:** PostgreSQL
- **Frontend:** Hotwire (Turbo/Stimulus), custom CSS
- **Hosting:** Cloud-based (AWS/GCP/Heroku)
- **Security:** SOC2 compliance path, encryption at rest/transit

### 5.2 Integrations

| System | Purpose | Priority |
|--------|---------|----------|
| CoreLogic | Property valuation | P0 (Critical) |
| DocuSign/equivalent | E-signatures | P1 (High) |
| Payment gateway | Income disbursement | P1 (High) |
| Investment manager API | Fund management | P1 (High) |
| Email service (SendGrid etc.) | Communications | P1 (High) |
| Identity verification | KYC/AML | P1 (High) |
| Analytics | Usage tracking | P2 (Medium) |
| CRM | Customer relationship | P3 (Low) |

### 5.3 Security & Compliance

- [ ] Data encryption (AES-256)
- [ ] TLS 1.3 for all communications
- [ ] Multi-factor authentication (staff mandatory, customers optional)
- [ ] Role-based access control
- [ ] Full audit logging
- [ ] GDPR/Privacy Act compliance
- [ ] Regular security assessments
- [ ] Disaster recovery plan

---

## 6. ARCADE GAMES (Admin Entertainment Feature)

### 6.1 Current Games

The platform includes retro arcade games accessible from the admin dashboard:

1. **Honky Pong** - Donkey Kong inspired platformer
2. **Lace Invaders** - Space Invaders variant
3. **Hackman** - Pac-Man style game
4. **DefendHer** - Defender-inspired shooter
5. **Hemorrhoids** - Asteroids clone
6. **Galaxian** - Classic shooter

### 6.2 Enhancement Requirements

**To make games more authentic to originals:**

- [ ] Accurate physics matching original arcade games
- [ ] Authentic 8-bit graphics and color palettes
- [ ] Original sound effects (where legally possible)
- [ ] Authentic scoring systems
- [ ] Original level progressions
- [ ] High score persistence
- [ ] Two-player modes (where applicable)
- [ ] Touch controls for mobile

**QUESTION FOR BUSINESS:** Should arcade be customer-facing for engagement, or admin-only for staff entertainment?

---

## 7. SUCCESS METRICS

### 7.1 Customer Metrics
- Quote-to-application conversion rate
- Application completion rate
- Time to approval
- Customer satisfaction (NPS)
- Support ticket volume

### 7.2 Business Metrics
- Total loan volume originated
- Average loan size
- Revenue per loan
- Customer acquisition cost
- Lifetime value
- Churn/prepayment rate

### 7.3 Operational Metrics
- System uptime
- Page load times
- API response times
- Error rates
- Support response times

---

## 8. OPEN QUESTIONS FOR BUSINESS

### Product Rules
1. What are the exact eligibility criteria for borrowers?
2. Are investment properties eligible in all markets?
3. What is the minimum/maximum loan amount?
4. What interest rate structure applies (fixed, variable, hybrid)?
5. Are there early repayment penalties?
6. How is the borrower's monthly income calculated and locked in?

### Stakeholder Access
7. What level of detail should wholesale funders see about individual loans?
8. Should referral partners track their customers post-settlement?
9. Should customers see investment performance or just income received?

### Technical
10. Which identity verification provider should be used?
11. Which e-signature platform is preferred?
12. What analytics/tracking requirements exist?

### Commercial
13. What is the launch market priority (AU, UK, US)?
14. What is the target go-live date for MVP?
15. Which features are MVP vs. Phase 2?

---

## 9. DOCUMENT APPROVAL

| Stakeholder | Name | Approval | Date |
|-------------|------|----------|------|
| Product Owner | | [ ] Approved | |
| Business Lead | | [ ] Approved | |
| Technical Lead | | [ ] Approved | |
| Compliance | | [ ] Approved | |
| Executive Sponsor | | [ ] Approved | |

---

## 10. NEXT STEPS

1. **Business Review:** Circulate to all business units
2. **Answer Open Questions:** Collect responses to Section 8
3. **Requirements Sign-off:** All stakeholders approve
4. **Technical Planning:** Detailed sprint planning
5. **Development:** Iterative build with business validation

---

*This document will be updated based on business feedback before development begins.*
